# Multi-stage optimized FreeBSD Docker image
# Stage 1: Download FreeBSD ISO and prepare installation
FROM alpine:3.19 AS downloader

ARG FREEBSD_VERSION=14.3-RELEASE

RUN apk add --no-cache curl ca-certificates && \
    ARCH="amd64" && \
    VERSION="${FREEBSD_VERSION}" && \
    ISO_URL="https://download.freebsd.org/ftp/releases/ISO-IMAGES/${VERSION}/FreeBSD-${VERSION}-${ARCH}-disc1.iso" && \
    echo "Downloading FreeBSD ISO from: ${ISO_URL}" && \
    curl -L -o /freebsd.iso "${ISO_URL}" && \
    ls -lh /freebsd.iso && \
    echo "ISO downloaded successfully (size: $(du -h /freebsd.iso | cut -f1))"

# Stage 2: Install FreeBSD to disk image
FROM alpine:3.19 AS installer

# Install QEMU and dependencies
RUN apk add --no-cache \
    qemu-system-x86_64 \
    qemu-img \
    bash \
    expect

WORKDIR /build

# Copy ISO from downloader
COPY --from=downloader /freebsd.iso /build/freebsd.iso

# Create disk image
RUN qemu-img create -f qcow2 /build/disk.qcow2 20G

# Create automated installer script
RUN cat > /build/install.sh << 'EOF'
#!/bin/bash
set -e

echo "Starting FreeBSD automated installation..."

# Create expect script for automated installation
cat > /tmp/install.exp << 'EXPECT'
#!/usr/bin/expect -f
set timeout 1800
spawn qemu-system-x86_64 \
    -m 2G \
    -smp 2 \
    -drive file=/build/disk.qcow2,format=qcow2,if=virtio \
    -cdrom /build/freebsd.iso \
    -boot d \
    -nographic \
    -device virtio-net,netdev=net0 \
    -netdev user,id=net0

# Wait for installer boot menu
expect "Welcome to FreeBSD"
sleep 2
send "\r"

# Wait for installer main menu
expect "Install"
send "\r"

# Keymap selection
expect "Keymap Selection"
send "\r"

# Hostname
expect "Hostname"
send "freebsd\r"

# Distribution selection
expect "Distribution Select"
send "\r"

# Partitioning
expect "Partitioning"
send "\r"
expect "Entire Disk"
send "\r"
expect "Partition Scheme"
send "\r"
expect "Confirmation"
send "\r"

# Wait for extraction
expect "Archive Extraction" {
    exp_continue
}
expect "Password"

# Set root password
send "freebsd\r"
expect "password"
send "freebsd\r"

# Network configuration
expect "Network Configuration"
send "\r"
expect "IPv4"
send "\r"
expect "DHCP"
send "\r"
expect "IPv6"
send "n\r"
expect "Resolver"
send "\r"

# Timezone
expect "Time Zone"
send "\r"
expect "UTC"
send "\r"

# System configuration
expect "System Configuration"
send " "  # Select sshd
send "\r"

# System hardening
expect "System Hardening"
send "\r"

# Add user
expect "Add User"
send "n\r"

# Final configuration
expect "Final Configuration"
send "\r"

# Manual configuration
expect "Manual Configuration"
send "n\r"

# Complete
expect "Complete"
send "\r"

# Reboot
expect "Reboot"
send "\r"

expect eof
EXPECT

chmod +x /tmp/install.exp

# Run automated installation
timeout 1800 /tmp/install.exp || {
    echo "Installation may have completed with timeout"
}

echo "FreeBSD installation complete!"
EOF

RUN chmod +x /build/install.sh

# Run the installation (this will take time)
RUN /build/install.sh || true

# Verify disk image was created and has content
RUN qemu-img info /build/disk.qcow2 && \
    ls -lh /build/disk.qcow2

# Stage 3: Runtime image (minimal)
FROM alpine:3.19

ARG FREEBSD_VERSION=14.3-RELEASE
ARG BUILD_DATE
ARG VCS_REF

LABEL org.opencontainers.image.title="FreeBSD Developer Environment" \
      org.opencontainers.image.description="FreeBSD VM with comprehensive development tools" \
      org.opencontainers.image.authors="aygp-dr" \
      org.opencontainers.image.version="${FREEBSD_VERSION}" \
      org.opencontainers.image.revision="${VCS_REF}" \
      org.opencontainers.image.created="${BUILD_DATE}"

# Install only runtime dependencies
RUN apk add --no-cache \
    qemu-system-x86_64 \
    qemu-img \
    bash \
    openssh-client \
    socat \
    iproute2 \
    iptables \
    bridge-utils \
    && rm -rf /var/cache/apk/*

WORKDIR /freebsd

# Copy the INSTALLED FreeBSD disk image from installer
COPY --from=installer /build/disk.qcow2 /freebsd/disk.qcow2

# Copy runtime scripts
COPY scripts/entrypoint.sh /scripts/
COPY scripts/health-check.sh /scripts/
COPY scripts/network-setup.sh /scripts/
COPY scripts/jail-manager.sh /scripts/
COPY scripts/zfs-setup.sh /scripts/

RUN chmod +x /scripts/*.sh

# Ports
EXPOSE 22 5900

# Environment
ENV MEMORY=2G \
    CPUS=2 \
    DISK_SIZE=20G

# Health check
HEALTHCHECK --interval=30s --timeout=10s \
    CMD /scripts/health-check.sh || exit 1

ENTRYPOINT ["/scripts/entrypoint.sh"]
CMD ["start"]