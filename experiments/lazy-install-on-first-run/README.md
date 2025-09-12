# Experiment: Lazy FreeBSD Installation

## Problem
Current Dockerfile takes 30+ minutes to build because it runs the ENTIRE FreeBSD installation during the Docker build process using QEMU without KVM acceleration.

## Hypothesis
By deferring FreeBSD installation to first container run, we can:
- Reduce build time from 30+ minutes to ~3 minutes
- Still provide the same end-user experience
- Make CI/CD pipelines actually usable

## Design
```
Current (SLOW):
  Docker Build:
    1. Download ISO (2 min)
    2. Install FreeBSD in QEMU (28+ min) ← THE PROBLEM
    3. Package image (30s)
    Total: 30+ minutes

New Approach (FAST):
  Docker Build:
    1. Download ISO (2 min)
    2. Package image with scripts (30s)
    Total: ~3 minutes
    
  First Container Run:
    1. Detect no installation
    2. Run FreeBSD installer (15-30 min, but with user's KVM)
    3. Start FreeBSD normally
```

## Testing Locally

```bash
# Build the experiment image (should take ~3 minutes)
cd experiments/lazy-install-on-first-run
time docker build -t freebsd-lazy .

# Run it (first run will install FreeBSD)
docker run -d --name freebsd-test --privileged -p 2222:22 freebsd-lazy

# Watch the installation
docker logs -f freebsd-test

# After installation completes, SSH in
ssh -p 2222 root@localhost
```

## Advantages
1. **Fast CI/CD**: 3-minute builds instead of 30+ minutes
2. **User KVM**: Installation uses user's KVM acceleration (much faster)
3. **Smaller layers**: Don't need to store installed disk in layers
4. **Cache friendly**: ISO download layer can be cached

## Disadvantages
1. **First run is slow**: User waits 15-30 min on first container start
2. **Not "instant"**: Container isn't immediately ready
3. **Storage**: Each container instance installs separately

## Metrics to Compare

| Metric | Current Approach | Lazy Install |
|--------|-----------------|--------------|
| Build time (CI) | 30+ min | ~3 min |
| Image size | ~2GB | ~1.3GB |
| First run | Instant | 15-30 min |
| Subsequent runs | Instant | Instant |
| CI/CD friendly | ❌ | ✅ |

## Decision
This experiment will help decide if we should switch to lazy installation for better CI/CD performance.