# Lightweight FreeBSD Docker Container Approach

## Current Problem
The current approach downloads the 1.3GB FreeBSD ISO during Docker build time, resulting in:
- Large Docker images (1.3GB+)
- Slow CI/CD builds (10-15 minutes just for ISO download)
- Bandwidth waste when pushing/pulling from registries
- Storage costs on Docker Hub

## Proposed Solution: Dynamic ISO Download

### Architecture
```
Docker Image (100MB):
├── Alpine Linux base (5MB)
├── QEMU + tools (95MB)
└── Entrypoint script

Runtime:
└── Downloads ISO on first start
    └── Caches locally for reuse
```

### Benefits
1. **Tiny Docker Image**: ~100MB vs 1.3GB+
2. **Fast CI/CD**: Builds in seconds, not minutes
3. **Same bandwidth cost**: ISO downloaded once per host
4. **Flexible**: Can specify FreeBSD version at runtime
5. **Better caching**: ISO cached on host, not in image layers

### Implementation

```dockerfile
# Lightweight Dockerfile
FROM alpine:3.19

RUN apk add --no-cache \
    qemu-system-x86_64 \
    qemu-img \
    curl \
    bash

COPY scripts/entrypoint.sh /scripts/
RUN chmod +x /scripts/entrypoint.sh

ENV FREEBSD_VERSION=14.2-RELEASE
ENTRYPOINT ["/scripts/entrypoint.sh"]
```

```bash
# entrypoint.sh
#!/bin/bash
ISO_DIR="/var/cache/freebsd-iso"
ISO_FILE="${ISO_DIR}/FreeBSD-${FREEBSD_VERSION}-amd64-disc1.iso"

if [ ! -f "$ISO_FILE" ]; then
    echo "Downloading FreeBSD ${FREEBSD_VERSION}..."
    mkdir -p "$ISO_DIR"
    curl -L -o "$ISO_FILE" \
        "https://download.freebsd.org/ftp/releases/amd64/amd64/ISO-IMAGES/${FREEBSD_VERSION}/FreeBSD-${FREEBSD_VERSION}-amd64-disc1.iso"
fi

# Create disk if not exists
if [ ! -f /freebsd/disk.qcow2 ]; then
    qemu-img create -f qcow2 /freebsd/disk.qcow2 20G
fi

# Start QEMU with the ISO
exec qemu-system-x86_64 \
    -m ${MEMORY:-2G} \
    -smp ${CPUS:-2} \
    -drive file=/freebsd/disk.qcow2,format=qcow2 \
    -cdrom "$ISO_FILE" \
    "$@"
```

### Usage
```bash
# First run downloads ISO (one-time cost)
docker run -v freebsd-iso:/var/cache/freebsd-iso \
           -e FREEBSD_VERSION=14.2-RELEASE \
           aygpdr/freebsd:lightweight

# Subsequent runs use cached ISO
docker run -v freebsd-iso:/var/cache/freebsd-iso \
           aygpdr/freebsd:lightweight

# Different version
docker run -v freebsd-iso:/var/cache/freebsd-iso \
           -e FREEBSD_VERSION=13.4-RELEASE \
           aygpdr/freebsd:lightweight
```

### Migration Path
1. Keep current "fat" image as `aygpdr/freebsd:14.2-with-iso`
2. Create new lightweight image as `aygpdr/freebsd:latest`
3. Document both approaches for different use cases

### Trade-offs
**Pros:**
- 93% smaller image size
- Instant builds
- Version flexibility
- Lower storage costs

**Cons:**
- First container start is slow (ISO download)
- Requires volume mount for ISO caching
- Network required on first run

## Recommendation
Implement the lightweight approach as the default, with the current approach available as a "batteries-included" alternative for offline/airgapped environments.