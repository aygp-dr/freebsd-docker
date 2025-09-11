---
name: "BUG-01: FreeBSD Never Actually Installed"
about: Critical issue where FreeBSD was completely missing from the Docker image
title: "[FIXED] FreeBSD was never installed - ISO download failed silently"
labels: bug, critical, fixed
assignees: aygp-dr
---

## 🐛 Bug Report: FreeBSD Never Actually Installed

### Summary
The FreeBSD Docker container appeared to work but **FreeBSD was never actually installed**. Users who ran the container only saw Alpine Linux because FreeBSD was completely missing.

### Root Cause Analysis

#### 1. Wrong ISO Download URL
```dockerfile
# ❌ BROKEN (404 Error)
ISO_URL="https://download.freebsd.org/releases/ISO-IMAGES/${VERSION}/FreeBSD-${VERSION}-${ARCH}-disc1.iso"

# ✅ FIXED
ISO_URL="https://download.freebsd.org/ftp/releases/ISO-IMAGES/${VERSION}/FreeBSD-${VERSION}-${ARCH}-disc1.iso"
```
Missing `/ftp/` in the path caused a 404 error that was silently ignored.

#### 2. Error Suppression Masked the Failure
```dockerfile
curl -L -o /freebsd.iso "${ISO_URL}" || true  # This || true hid the 404!
```

#### 3. ISO Not Copied to Final Stage
```dockerfile
# Stage 3: Runtime (ISO was missing!)
COPY --from=builder /build/disk.qcow2 /freebsd/disk.qcow2
# ❌ No ISO copy - FreeBSD couldn't be installed
```

### Impact
- All published images `aygpdr/freebsd:*` before Sept 11, 2025 contained **no FreeBSD**
- Users got Alpine Linux with QEMU but no FreeBSD VM
- The advertised functionality was completely broken

### Discovery Timeline
1. User ran container: `docker run -it aygpdr/freebsd:latest`
2. Got Alpine prompt instead of FreeBSD
3. Created documentation explaining "architecture" (Alpine → QEMU → FreeBSD)
4. User noticed: "i think you really need to confirm that the correct iso is downloaded"
5. Investigation revealed FreeBSD was never there

### Resolution
Created `Dockerfile.fixed` with:
- ✅ Correct ISO URL with `/ftp/` path
- ✅ Automated FreeBSD installation via expect scripts
- ✅ ISO preserved in final image
- ✅ Verification steps added

### Lessons Learned
1. **Never suppress errors during critical operations** - `|| true` masked the failure
2. **Verify downloads succeeded** - Check file sizes and hashes
3. **Test actual functionality** - "It builds" ≠ "It works"
4. **Multi-stage builds can hide issues** - Resources not copied are lost

### Verification
```bash
# Pull the fixed image
docker pull aygpdr/freebsd:latest

# Start container
docker run -d --name test --privileged -p 2222:22 aygpdr/freebsd:latest

# Wait for boot (60s)
sleep 60

# SSH into FreeBSD (password: freebsd)
ssh -p 2222 root@localhost

# Verify it's FreeBSD
uname -a
# Expected: FreeBSD freebsd 14.3-RELEASE ...
```

### Status
✅ **FIXED** - New images published to Docker Hub include FreeBSD

---
*"lol; we tried" - Sometimes the most obvious things are completely broken*