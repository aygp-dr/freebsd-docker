#!/bin/bash
set -e

echo "=================================="
echo "Lazy Installation Experiment Test"
echo "=================================="
echo

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Time the build
echo -e "${YELLOW}Building image (should take ~3 minutes)...${NC}"
START_TIME=$(date +%s)

docker build -t freebsd-lazy . || {
    echo "Build failed!"
    exit 1
}

END_TIME=$(date +%s)
BUILD_TIME=$((END_TIME - START_TIME))

echo -e "${GREEN}✓ Build completed in ${BUILD_TIME} seconds${NC}"
echo

# Check image size
echo "Image size:"
docker images freebsd-lazy --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}"
echo

# Compare with current approach
if [ $BUILD_TIME -lt 300 ]; then
    echo -e "${GREEN}SUCCESS: Build time under 5 minutes!${NC}"
    echo "This is 6x faster than the current 30+ minute builds!"
else
    echo -e "${YELLOW}Build took longer than expected: ${BUILD_TIME}s${NC}"
fi

echo
echo "To test the container (will install FreeBSD on first run):"
echo "  docker run -d --name freebsd-lazy-test --privileged -p 2223:22 freebsd-lazy"
echo "  docker logs -f freebsd-lazy-test"
echo
echo "Note: First run will take 15-30 minutes to install FreeBSD"
echo "      But this happens on user's machine with KVM, not in CI!"