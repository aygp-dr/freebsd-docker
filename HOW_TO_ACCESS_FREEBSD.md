# How to Access FreeBSD in the Container

## ⚠️ Important: Understanding the Architecture

When you run this Docker container, you are **NOT** directly in FreeBSD. The architecture is:

```
Your Host OS (Linux/macOS/Windows)
    ↓
Docker Container (Alpine Linux)
    ↓
QEMU Virtual Machine
    ↓
FreeBSD 14.3-RELEASE
```

## Why You See Alpine Linux

When you run:
```bash
docker run -it aygpdr/freebsd:latest /bin/sh
```

You're accessing the **Alpine Linux container shell**, not FreeBSD. This is expected! FreeBSD runs inside a QEMU VM within this container.

## How to Access FreeBSD

### Method 1: SSH (Recommended)

1. **Start the container with SSH port exposed:**
```bash
docker run -d --name freebsd --privileged -p 2222:22 aygpdr/freebsd:latest
```

2. **Wait for FreeBSD to boot (30-60 seconds):**
```bash
# Check if FreeBSD is ready
docker logs freebsd
```

3. **SSH into FreeBSD:**
```bash
ssh -p 2222 root@localhost
# Password: freebsd
```

Now you're in FreeBSD:
```bash
root@freebsd:~ # uname -a
FreeBSD freebsd 14.3-RELEASE FreeBSD 14.3-RELEASE #0 releng/14.3-n267312-a5e672d1b468: Mon Nov  4 10:00:00 UTC 2024
```

### Method 2: Docker Exec + SSH

1. **Start container:**
```bash
docker run -d --name freebsd --privileged aygpdr/freebsd:latest
```

2. **Wait for boot, then SSH from within container:**
```bash
docker exec -it freebsd sh -c "ssh root@localhost"
# Password: freebsd
```

### Method 3: Console Access (Advanced)

1. **Start container interactively:**
```bash
docker run -it --privileged aygpdr/freebsd:latest
```

2. **You'll see the Alpine prompt. The FreeBSD VM is booting in the background.**

3. **Access QEMU monitor:**
```bash
# Press Ctrl+A, then C to enter QEMU monitor
(qemu) info status
VM status: running

# Press Ctrl+A, then C again to return to VM console
```

### Method 4: VNC Access (GUI)

1. **Enable VNC:**
```bash
docker run -d --name freebsd --privileged \
  -p 5900:5900 \
  -e ENABLE_VNC=true \
  aygpdr/freebsd:latest
```

2. **Connect with VNC client:**
```bash
vncviewer localhost:5900
```

## Verifying You're in FreeBSD

Once connected, verify you're actually in FreeBSD:

```bash
# Check OS
uname -a
# FreeBSD freebsd 14.3-RELEASE ...

# Check FreeBSD version
freebsd-version
# 14.3-RELEASE

# Check available commands
which pkg
# /usr/sbin/pkg

# Check jails
jls
# No jails running

# Check ZFS
zpool list
# no pools available
```

## Common Issues

### "I only see Alpine Linux!"
**Solution:** You're in the container layer. Use SSH to access FreeBSD VM.

### "SSH connection refused"
**Solution:** FreeBSD VM needs 30-60 seconds to boot. Check logs:
```bash
docker logs container-name
```

### "No network in FreeBSD"
**Solution:** Check network mode:
```bash
docker run -d --privileged \
  -e NETWORK_MODE=user \
  aygpdr/freebsd:latest
```

### "Performance is slow"
**Solution:** Enable KVM acceleration:
```bash
docker run -d --privileged \
  --device /dev/kvm \
  aygpdr/freebsd:latest
```

## Test Script

Run the included test to verify everything works:
```bash
./test-freebsd-vm.sh
```

## Architecture Diagram

```
┌─────────────────────────────────────┐
│         Host Operating System        │
│        (Linux/macOS/Windows)         │
└─────────────────┬───────────────────┘
                  │
┌─────────────────▼───────────────────┐
│          Docker Engine              │
└─────────────────┬───────────────────┘
                  │
┌─────────────────▼───────────────────┐
│     Alpine Linux Container          │
│  • QEMU installed                   │
│  • Scripts for management           │
│  • Port forwarding                  │
└─────────────────┬───────────────────┘
                  │
┌─────────────────▼───────────────────┐
│      QEMU Virtual Machine           │
│  • Full system emulation            │
│  • KVM acceleration (optional)      │
└─────────────────┬───────────────────┘
                  │
┌─────────────────▼───────────────────┐
│    FreeBSD 14.3-RELEASE             │
│  • Full FreeBSD environment         │
│  • Jails support                    │
│  • ZFS filesystem                   │
│  • Development tools                │
└─────────────────────────────────────┘
```

## Quick Test Commands

```bash
# Test 1: Verify container OS (should show Alpine)
docker run --rm aygpdr/freebsd:latest cat /etc/os-release

# Test 2: Verify QEMU is installed
docker run --rm aygpdr/freebsd:latest qemu-system-x86_64 --version

# Test 3: Full FreeBSD test (requires patience)
docker run -d --name test --privileged -p 2222:22 aygpdr/freebsd:latest
sleep 60  # Wait for boot
ssh -p 2222 root@localhost uname -a  # Password: freebsd
docker stop test && docker rm test
```