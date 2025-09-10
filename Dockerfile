FROM alpine:3.19

ARG FREEBSD_VERSION=14.0-RELEASE

RUN apk add --no-cache \
    qemu-system-x86_64 \
    qemu-img \
    curl \
    bash \
    openssh-client

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
