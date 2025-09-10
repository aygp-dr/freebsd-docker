FROM alpine:3.19

# Build arguments
ARG FREEBSD_VERSION=14.0-RELEASE
ARG BUILD_DATE
ARG VCS_REF

# Labels for metadata
LABEL org.opencontainers.image.title="FreeBSD Docker" \
      org.opencontainers.image.description="FreeBSD virtual machines in Docker with QEMU, jails, and ZFS support" \
      org.opencontainers.image.authors="aygp-dr" \
      org.opencontainers.image.vendor="aygp-dr" \
      org.opencontainers.image.url="https://github.com/aygp-dr/freebsd-docker" \
      org.opencontainers.image.source="https://github.com/aygp-dr/freebsd-docker" \
      org.opencontainers.image.documentation="https://github.com/aygp-dr/freebsd-docker/blob/main/README.md" \
      org.opencontainers.image.licenses="BSD-3-Clause" \
      org.opencontainers.image.version="${FREEBSD_VERSION}" \
      org.opencontainers.image.revision="${VCS_REF}" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      freebsd.version="${FREEBSD_VERSION}"

RUN apk add --no-cache \
    qemu-system-x86_64 \
    qemu-img \
    curl \
    bash \
    openssh-client \
    socat \
    bridge-utils \
    iproute2 \
    iptables \
    dnsmasq

WORKDIR /freebsd

RUN ARCH="amd64" && \
    VERSION="${FREEBSD_VERSION}" && \
    ISO_URL="https://download.freebsd.org/releases/${ARCH}/${VERSION}/FreeBSD-${VERSION}-${ARCH}-disc1.iso" && \
    curl -L -o freebsd.iso "${ISO_URL}"

COPY scripts/ /scripts/
RUN chmod +x /scripts/*

RUN qemu-img create -f qcow2 /freebsd/disk.qcow2 10G
RUN /scripts/install-freebsd.sh

EXPOSE 22
ENV MEMORY=1G CPUS=2

HEALTHCHECK --interval=30s --timeout=10s \
    CMD /scripts/health-check.sh

ENTRYPOINT ["/scripts/entrypoint.sh"]
CMD ["start"]
