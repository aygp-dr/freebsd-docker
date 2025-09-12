# Current Status - FreeBSD Docker Project

## Latest Build Status
- **FreeBSD Version**: 14.2-RELEASE
- **Docker Hub**: `aygpdr/freebsd:latest` ✅
- **GHCR**: Permission issues (see [GHCR_SETUP.md](GHCR_SETUP.md)) ❌
- **Build Time**: ~30+ minutes (working on fix in [#4](https://github.com/aygp-dr/freebsd-docker/issues/4))

## Recent Fixes

### ✅ Fixed: FreeBSD ISO Download
- **Problem**: Wrong URL path caused 404 errors
- **Solution**: Corrected path to `/ftp/releases/ISO-IMAGES/14.2/`
- **Status**: Fixed and deployed

### ✅ Added: ARM64 Mac Support
- **Problem**: No ARM64 FreeBSD ISOs exist
- **Solution**: Use `--platform linux/amd64` with Rosetta emulation
- **Script**: [run-on-arm64-mac.sh](run-on-arm64-mac.sh)
- **Issue**: [#3](https://github.com/aygp-dr/freebsd-docker/issues/3)

## Known Issues

### 🔴 Critical: 30+ Minute Build Times
- **Cause**: FreeBSD installs during Docker build (no KVM in CI)
- **Impact**: GitHub Actions timeouts, expensive CI minutes
- **Proposed Fix**: Lazy installation on first run
- **Experiment**: [experiments/lazy-install-on-first-run/](experiments/lazy-install-on-first-run/)
- **Tracking**: [#4](https://github.com/aygp-dr/freebsd-docker/issues/4)

### 🟡 GHCR Publishing Fails
- **Error**: "installation not allowed to Write organization package"
- **Fix**: Enable write permissions in repo settings
- **Guide**: [GHCR_SETUP.md](GHCR_SETUP.md)

## How It Works

```
Your Computer
     ↓
Docker Container (Alpine Linux)
     ↓
QEMU Virtual Machine
     ↓
FreeBSD 14.2-RELEASE
```

When you run the container, you're in Alpine Linux. FreeBSD runs inside QEMU within the container. Access FreeBSD via SSH on port 2222.

## Quick Test

```bash
# Pull latest (might be broken due to ongoing fixes)
docker pull aygpdr/freebsd:latest

# Run container
docker run -d --name test --privileged -p 2222:22 aygpdr/freebsd:latest

# Wait for FreeBSD to boot (60-90 seconds)
sleep 90

# SSH into FreeBSD (password: freebsd)
ssh -p 2222 root@localhost

# Verify it's FreeBSD
uname -a
# Should show: FreeBSD ... 14.2-RELEASE ...
```

## Next Steps

1. **Immediate**: Monitor current build to see if ISO downloads correctly
2. **Short-term**: Implement lazy installation to fix 30+ minute builds
3. **Medium-term**: Fix GHCR permissions for redundant registry
4. **Long-term**: Consider pre-built disk images for instant startup

## Development

Active experiments in [experiments/](experiments/) directory:
- `lazy-install-on-first-run/` - Reduce build time from 30+ min to 3 min

## Last Updated
2025-09-12 (September 12, 2025)