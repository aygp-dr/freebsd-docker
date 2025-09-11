#!/bin/bash
set -e

echo "=========================================="
echo "FreeBSD Docker on ARM64 Mac (Apple Silicon)"
echo "=========================================="
echo
echo "⚠️  IMPORTANT: FreeBSD doesn't have native ARM64 support."
echo "   The container uses x86_64 emulation via QEMU."
echo "   This will be SLOW but functional."
echo

# Check if Docker is running
if ! docker info >/dev/null 2>&1; then
    echo "❌ Docker is not running!"
    echo "Please start Docker Desktop first."
    exit 1
fi

echo "✓ Docker is running"
echo

# Check Docker platform emulation
echo "Checking Docker platform support..."
docker run --rm --platform linux/amd64 alpine:3.19 uname -m || {
    echo "❌ Docker platform emulation not working!"
    echo "Enable 'Use Rosetta for x86/amd64 emulation' in Docker Desktop settings."
    exit 1
}

echo "✓ x86_64 emulation is available"
echo

# Clean up any existing container
docker stop freebsd-arm-test 2>/dev/null || true
docker rm freebsd-arm-test 2>/dev/null || true

# Pull and run with platform override
echo "Pulling FreeBSD image (forcing x86_64)..."
docker pull --platform linux/amd64 aygpdr/freebsd:latest

echo
echo "Starting FreeBSD container (x86_64 emulated)..."
docker run -d \
    --name freebsd-arm-test \
    --platform linux/amd64 \
    --privileged \
    -p 2222:22 \
    aygpdr/freebsd:latest

echo
echo "⏳ Waiting for FreeBSD to boot (this will be SLOW on ARM64)..."
echo "   Expected wait time: 2-5 minutes due to nested emulation"
echo

# Wait longer for ARM64 emulation
timeout=300  # 5 minutes
elapsed=0
while [ $elapsed -lt $timeout ]; do
    if docker exec freebsd-arm-test nc -z localhost 22 2>/dev/null; then
        echo "✅ FreeBSD SSH port is responding!"
        break
    fi
    echo "   Still waiting... ($elapsed/$timeout seconds)"
    sleep 15
    elapsed=$((elapsed + 15))
done

if [ $elapsed -ge $timeout ]; then
    echo "⚠️  FreeBSD is taking longer than expected. Checking logs..."
    docker logs freebsd-arm-test | tail -20
    echo
    echo "The container is still running. It may need more time."
fi

echo
echo "=========================================="
echo "TESTING INSTRUCTIONS"
echo "=========================================="
echo
echo "1. Test Alpine container layer:"
echo "   docker exec freebsd-arm-test cat /etc/os-release"
echo
echo "2. Check QEMU process:"
echo "   docker exec freebsd-arm-test pgrep qemu-system"
echo
echo "3. SSH into FreeBSD (when ready):"
echo "   ssh -p 2222 root@localhost"
echo "   Password: freebsd"
echo
echo "4. Clean up when done:"
echo "   docker stop freebsd-arm-test && docker rm freebsd-arm-test"
echo
echo "⚠️  Performance Note:"
echo "   You're running x86_64 FreeBSD → in x86_64 QEMU → in x86_64 Alpine"
echo "   → in x86_64 Docker → on ARM64 macOS via Rosetta emulation."
echo "   This is NESTED EMULATION and will be very slow!"
echo
echo "For better performance on ARM64 Macs:"
echo "   - Use a cloud x86_64 instance"
echo "   - Use GitHub Codespaces"
echo "   - Wait for native ARM64 FreeBSD support"