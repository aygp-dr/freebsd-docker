# Multi-stage optimized FreeBSD Docker image
# Stage 1: Download FreeBSD ISO and prepare installation
FROM alpine:3.19 AS downloader

ARG FREEBSD_VERSION=14.1-RELEASE

RUN apk add --no-cache curl ca-certificates && \
    ARCH="amd64" && \
    VERSION="${FREEBSD_VERSION}" && \
    ISO_URL="https://download.freebsd.org/releases/${ARCH}/${VERSION}/FreeBSD-${VERSION}-${ARCH}-disc1.iso" && \
    curl -L -o /freebsd.iso "${ISO_URL}" && \
    ls -lh /freebsd.iso

# Stage 2: Build QEMU image with FreeBSD
FROM alpine:3.19 AS builder

# Install QEMU and build tools
RUN apk add --no-cache \
    qemu-system-x86_64 \
    qemu-img \
    bash

WORKDIR /build

# Copy ISO from downloader
COPY --from=downloader /freebsd.iso /build/freebsd.iso

# Create disk image
RUN qemu-img create -f qcow2 /build/disk.qcow2 20G

# Copy installation scripts
COPY scripts/install-freebsd.sh /build/
RUN chmod +x /build/install-freebsd.sh

# Install FreeBSD with development tools
RUN cat > /build/install.conf <<'EOF' && \
#!/bin/sh
# FreeBSD automated installation with dev tools
PARTITIONS="AUTO"
DISTRIBUTIONS="base.txz kernel.txz lib32.txz"

# Set root password
echo 'freebsd' | pw usermod root -h 0

# Configure network
echo 'hostname="freebsd-dev"' >> /etc/rc.conf
echo 'ifconfig_vtnet0="DHCP"' >> /etc/rc.conf
echo 'sshd_enable="YES"' >> /etc/rc.conf

# Configure SSH
echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config
echo 'PasswordAuthentication yes' >> /etc/ssh/sshd_config

# Bootstrap pkg
env ASSUME_ALWAYS_YES=YES pkg bootstrap -f

# Install core development tools to match host environment
pkg install -y \
    # Core build tools
    gmake \
    cmake \
    ninja \
    meson \
    autoconf \
    automake \
    libtool \
    pkgconf \
    # Essential CLI tools
    bash \
    zsh \
    fish \
    tmux \
    git \
    gh \
    curl \
    wget \
    rsync \
    # Modern CLI tools
    ripgrep \
    fd-find \
    bat \
    eza \
    fzf \
    jq \
    yq \
    delta \
    difftastic \
    # Text processing
    gsed \
    gawk \
    miller \
    # Editors - IMPORTANT: Latest Emacs
    emacs-devel \
    vim \
    neovim \
    # Programming languages
    python311 \
    python39 \
    py311-pip \
    py311-virtualenv \
    py311-poetry \
    ruby32 \
    ruby32-gems \
    rbenv \
    guile3 \
    node22 \
    npm-node22 \
    yarn-node22 \
    openjdk17 \
    # Clojure/Babashka
    clojure \
    leiningen \
    # Rust toolchain
    rust \
    cargo \
    rustup \
    # Go
    go121 \
    # Terraform and infrastructure
    terraform \
    packer \
    vault \
    # Haskell
    ghc \
    hs-cabal-install \
    hs-stack \
    # Development libraries
    llvm17 \
    gcc13 \
    binutils \
    # Container tools
    podman \
    buildah \
    # Process monitoring
    htop \
    btop \
    ncdu \
    duf \
    # Network tools
    nmap \
    netcat \
    socat \
    mtr \
    # VPN and connectivity
    tailscale \
    wireguard-tools \
    # Database clients
    postgresql16-client \
    redis \
    sqlite3 \
    # Documentation
    mdbook \
    pandoc

# Install Babashka separately (not in ports)
fetch https://github.com/babashka/babashka/releases/download/v1.12.197/babashka-1.12.197-freebsd-amd64.tar.gz
tar xzf babashka-*.tar.gz -C /usr/local/bin/
rm babashka-*.tar.gz

# Install starship prompt
fetch -o - https://starship.rs/install.sh | sh -s -- -y

# Install tools via cargo
export CARGO_HOME=/usr/local/cargo
export PATH=$CARGO_HOME/bin:$PATH
cargo install --locked \
    jj \
    tokei \
    hyperfine \
    sd \
    dust \
    procs \
    bottom \
    gitui \
    zoxide

# Install tfenv for terraform version management
git clone --depth=1 https://github.com/tfutils/tfenv.git /usr/local/tfenv
ln -s /usr/local/tfenv/bin/* /usr/local/bin/

# Setup shell configurations
echo 'eval "$(starship init bash)"' >> /etc/profile
echo 'eval "$(starship init zsh)"' >> /etc/zsh/zshrc

# Validation step - ensure all critical tools are installed
cat > /usr/local/bin/validate-env <<'VALIDATE'
#!/bin/sh
echo "Validating FreeBSD development environment..."
failed=0

# Core tools that must exist
for tool in gmake git ripgrep fd-find gsed python3.11 ruby guile node npm cargo go rustc ghc terraform emacs jj bb starship tailscale; do
    if ! command -v $tool >/dev/null 2>&1; then
        echo "❌ Missing: $tool"
        failed=1
    else
        echo "✓ Found: $tool ($(command -v $tool))"
    fi
done

# Check package count
pkg_count=$(pkg info | wc -l)
echo "📦 Total packages installed: $pkg_count"

# Check disk usage
echo "💾 Disk usage:"
df -h /

if [ $failed -eq 1 ]; then
    echo "⚠️  Some tools are missing!"
    exit 1
else
    echo "✅ Environment validation successful!"
fi
VALIDATE
chmod +x /usr/local/bin/validate-env

# Run validation
/usr/local/bin/validate-env

# Clean package cache
pkg clean -y
pkg autoremove -y

# Remove unnecessary files
rm -rf /var/cache/pkg/*
rm -rf /tmp/*
rm -rf /usr/ports/*
rm -rf /usr/src/*
rm -rf /usr/obj/*
EOF
    /build/install-freebsd.sh || true

# Remove ISO after installation
RUN rm -f /build/freebsd.iso

# Stage 3: Runtime image (minimal)
FROM alpine:3.19

ARG FREEBSD_VERSION=14.1-RELEASE
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
    # Networking tools for bridge mode
    iproute2 \
    iptables \
    bridge-utils \
    # Minimal size - no dnsmasq, curl in runtime
    && rm -rf /var/cache/apk/*

WORKDIR /freebsd

# Copy built disk image from builder
COPY --from=builder /build/disk.qcow2 /freebsd/disk.qcow2

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