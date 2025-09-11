#!/bin/bash
set -e

echo "=========================================="
echo "FreeBSD Docker Image Fix Verification"
echo "=========================================="
echo
echo "This script verifies that the FreeBSD ISO is properly downloaded"
echo "and FreeBSD is actually accessible in the container."
echo

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}Note: This requires Docker to be running on your system.${NC}"
echo

# Step 1: Pull the latest image
echo "1. Pulling latest image from Docker Hub..."
docker pull aygpdr/freebsd:latest || {
    echo -e "${RED}Failed to pull image. Is Docker running?${NC}"
    exit 1
}

# Step 2: Check image layers and size
echo
echo "2. Checking image size (should be >1GB if FreeBSD ISO is included)..."
docker images aygpdr/freebsd:latest --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}"

# Step 3: Verify ISO is present in the container
echo
echo "3. Checking if FreeBSD ISO exists in the container..."
docker run --rm aygpdr/freebsd:latest ls -lh /freebsd/ | grep -E "(freebsd.iso|disk.qcow2)" || {
    echo -e "${RED}FreeBSD ISO or disk image not found!${NC}"
}

# Step 4: Check if QEMU can start
echo
echo "4. Verifying QEMU can start..."
docker run --rm aygpdr/freebsd:latest qemu-system-x86_64 --version | head -1

# Step 5: Start container and wait for FreeBSD
echo
echo "5. Starting container with FreeBSD VM..."
echo "   This will take 60-90 seconds for FreeBSD to boot..."

# Clean up any existing test container
docker stop freebsd-test 2>/dev/null || true
docker rm freebsd-test 2>/dev/null || true

# Start the container
docker run -d --name freebsd-test --privileged -p 2222:22 aygpdr/freebsd:latest

# Wait for container to be ready
sleep 5
if ! docker ps | grep -q freebsd-test; then
    echo -e "${RED}Container failed to start!${NC}"
    docker logs freebsd-test
    exit 1
fi

echo "   Container started. Waiting for FreeBSD to boot..."

# Monitor boot progress
timeout=90
elapsed=0
while [ $elapsed -lt $timeout ]; do
    if docker exec freebsd-test nc -z localhost 22 2>/dev/null; then
        echo -e "${GREEN}✓ FreeBSD SSH port is responding!${NC}"
        break
    fi
    echo "   Waiting... ($elapsed/$timeout seconds)"
    sleep 10
    elapsed=$((elapsed + 10))
done

if [ $elapsed -ge $timeout ]; then
    echo -e "${YELLOW}⚠ FreeBSD may not have booted yet. Checking container logs...${NC}"
    docker logs freebsd-test | tail -20
fi

# Step 6: Try to connect to FreeBSD
echo
echo "6. Attempting to verify FreeBSD is running..."
echo "   If you have sshpass installed, we'll try to connect automatically."
echo "   Otherwise, you can manually test with: ssh -p 2222 root@localhost (password: freebsd)"

if command -v sshpass >/dev/null 2>&1; then
    echo
    echo "Testing FreeBSD access..."
    if sshpass -p 'freebsd' ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 \
        -p 2222 root@localhost 'uname -a' 2>/dev/null; then
        echo -e "${GREEN}✅ SUCCESS! FreeBSD is running and accessible!${NC}"
        echo
        echo "FreeBSD version:"
        sshpass -p 'freebsd' ssh -o StrictHostKeyChecking=no -p 2222 root@localhost 'freebsd-version'
    else
        echo -e "${YELLOW}Could not connect to FreeBSD yet. It may still be booting.${NC}"
    fi
else
    echo
    echo "To verify FreeBSD is working, run:"
    echo "  ssh -p 2222 root@localhost"
    echo "  Password: freebsd"
    echo
    echo "Then run: uname -a"
    echo "Expected output: FreeBSD freebsd 14.3-RELEASE ..."
fi

# Step 7: Cleanup
echo
echo "7. Cleanup (keeping container running for manual testing)..."
echo "   To stop and remove the test container:"
echo "   docker stop freebsd-test && docker rm freebsd-test"
echo

# Summary
echo "=========================================="
echo "VERIFICATION SUMMARY"
echo "=========================================="

# Check results
if docker exec freebsd-test ls /freebsd/freebsd.iso >/dev/null 2>&1; then
    echo -e "${GREEN}✓ FreeBSD ISO is present in the image${NC}"
else
    echo -e "${RED}✗ FreeBSD ISO is missing${NC}"
fi

if docker exec freebsd-test pgrep qemu-system >/dev/null 2>&1; then
    echo -e "${GREEN}✓ QEMU is running${NC}"
else
    echo -e "${YELLOW}⚠ QEMU process not detected (may still be starting)${NC}"
fi

if docker exec freebsd-test nc -z localhost 22 2>/dev/null; then
    echo -e "${GREEN}✓ FreeBSD SSH port is open${NC}"
else
    echo -e "${YELLOW}⚠ FreeBSD SSH not ready (may need more time)${NC}"
fi

echo
echo "Container 'freebsd-test' is still running for manual testing."
echo "View logs with: docker logs freebsd-test"