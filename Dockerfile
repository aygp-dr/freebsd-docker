# Lightweight FreeBSD Docker image - downloads ISO at runtime
FROM alpine:3.19

ARG BUILD_DATE
ARG VCS_REF
ARG FREEBSD_VERSION=14.2-RELEASE

LABEL org.opencontainers.image.title="FreeBSD Lightweight" \
      org.opencontainers.image.description="FreeBSD VM environment that downloads ISO at runtime for faster CI/CD" \
      org.opencontainers.image.authors="aygp-dr" \
      org.opencontainers.image.version="${FREEBSD_VERSION}" \
      org.opencontainers.image.revision="${VCS_REF}" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.source="https://github.com/aygp-dr/freebsd-docker" \
      freebsd.version="${FREEBSD_VERSION}"

# Install runtime dependencies only - no ISO download
RUN apk add --no-cache \
    qemu-system-x86_64 \
    qemu-img \
    bash \
    curl \
    ca-certificates \
    openssh-client \
    socat \
    iproute2 \
    iptables \
    bridge-utils \
    && rm -rf /var/cache/apk/*

WORKDIR /freebsd

# Copy scripts
COPY scripts/entrypoint.sh /scripts/
COPY scripts/health-check.sh /scripts/
COPY scripts/network-setup.sh /scripts/
COPY scripts/jail-manager.sh /scripts/
COPY scripts/zfs-setup.sh /scripts/

RUN chmod +x /scripts/*.sh

# Create empty disk image (will be initialized on first boot)
RUN qemu-img create -f qcow2 /freebsd/disk.qcow2 20G

# Ports
EXPOSE 22 5900

# Environment
ENV FREEBSD_VERSION=${FREEBSD_VERSION} \
    ISO_CACHE_DIR=/var/cache/freebsd-iso \
    MEMORY=2G \
    CPUS=2 \
    DISK_SIZE=20G

# Volume for ISO cache - shared across containers
VOLUME ["/var/cache/freebsd-iso", "/freebsd/data"]

# Health check
HEALTHCHECK --interval=30s --timeout=10s \
    CMD /scripts/health-check.sh || exit 1

ENTRYPOINT ["/scripts/entrypoint.sh"]
CMD ["start"]