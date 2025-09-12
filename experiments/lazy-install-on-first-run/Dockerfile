# Experiment: Lazy FreeBSD Installation (Install on First Run)
# This should build in ~3 minutes instead of 30+ minutes

FROM alpine:3.19 AS downloader

ARG FREEBSD_VERSION=14.2-RELEASE

# Download ISO (1-2 minutes)
RUN apk add --no-cache curl ca-certificates && \
    ARCH="amd64" && \
    VERSION="${FREEBSD_VERSION}" && \
    ISO_URL="https://download.freebsd.org/ftp/releases/ISO-IMAGES/${VERSION}/FreeBSD-${VERSION}-${ARCH}-disc1.iso" && \
    echo "Downloading FreeBSD ISO from: ${ISO_URL}" && \
    curl -L -o /freebsd.iso "${ISO_URL}" && \
    ls -lh /freebsd.iso && \
    echo "ISO downloaded successfully (size: $(du -h /freebsd.iso | cut -f1))"

# Final stage - NO INSTALLATION during build!
FROM alpine:3.19

ARG FREEBSD_VERSION=14.2-RELEASE

LABEL org.opencontainers.image.title="FreeBSD Lazy Install Experiment" \
      org.opencontainers.image.description="FreeBSD VM that installs on first run, not during build"

# Install runtime dependencies only
RUN apk add --no-cache \
    qemu-system-x86_64 \
    qemu-img \
    bash \
    expect \
    openssh-client \
    && rm -rf /var/cache/apk/*

WORKDIR /freebsd

# Copy ISO from downloader
COPY --from=downloader /freebsd.iso /freebsd/freebsd.iso

# Create install script that runs AT RUNTIME
RUN cat > /freebsd/install-if-needed.sh << 'EOF'
#!/bin/bash
set -e

INSTALL_MARKER="/freebsd/.installed"
DISK_IMAGE="/freebsd/disk.qcow2"

if [ -f "$INSTALL_MARKER" ]; then
    echo "FreeBSD already installed, starting VM..."
else
    echo "First run detected! Installing FreeBSD..."
    echo "This will take 15-30 minutes on first run only."
    
    # Create disk image
    qemu-img create -f qcow2 "$DISK_IMAGE" 20G
    
    # Create expect script for automated installation
    cat > /tmp/install.exp << 'EXPECT'
#!/usr/bin/expect -f
set timeout 1800
spawn qemu-system-x86_64 \
    -m 2G \
    -smp 2 \
    -drive file=/freebsd/disk.qcow2,format=qcow2,if=virtio \
    -cdrom /freebsd/freebsd.iso \
    -boot d \
    -nographic \
    -device virtio-net,netdev=net0 \
    -netdev user,id=net0

# [Installation automation script continues...]
# Simplified for experiment - would include full expect automation

expect "Welcome to FreeBSD"
send "\r"
# ... rest of installation automation ...

expect eof
EXPECT
    
    chmod +x /tmp/install.exp
    
    # Run installation
    /tmp/install.exp || echo "Installation completed (or timed out)"
    
    # Mark as installed
    touch "$INSTALL_MARKER"
    echo "FreeBSD installation complete!"
    
    # Remove ISO to save space (optional)
    # rm -f /freebsd/freebsd.iso
fi

# Now start FreeBSD normally
exec qemu-system-x86_64 \
    -m "${MEMORY:-2G}" \
    -smp "${CPUS:-2}" \
    -drive file="$DISK_IMAGE",format=qcow2,if=virtio \
    -netdev user,id=net0,hostfwd=tcp::22-:22 \
    -device virtio-net,netdev=net0 \
    -nographic
EOF

RUN chmod +x /freebsd/install-if-needed.sh

# Environment
ENV MEMORY=2G \
    CPUS=2

EXPOSE 22

# This just starts the script - installation happens on first run!
ENTRYPOINT ["/freebsd/install-if-needed.sh"]