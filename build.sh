#!/bin/bash
# Build script for FreeBSD Docker image
# For Linux systems with Docker installed

set -e

# Configuration
DOCKER_USER="${DOCKER_USER:-aygp-dr}"
IMAGE_NAME="${IMAGE_NAME:-freebsd}"
FREEBSD_VERSION="${1:-14.0-RELEASE}"
PUSH="${2:-false}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if running on Linux
if [[ "$OSTYPE" != "linux-gnu"* ]]; then
    echo -e "${RED}Error: This script requires Linux with Docker${NC}"
    echo "On FreeBSD, use GitHub Actions to build: https://github.com/aygp-dr/freebsd-docker/actions"
    exit 1
fi

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Error: Docker is not installed${NC}"
    echo "Install Docker: https://docs.docker.com/engine/install/"
    exit 1
fi

# Check if Docker daemon is running
if ! docker info &> /dev/null; then
    echo -e "${RED}Error: Docker daemon is not running${NC}"
    echo "Start Docker: sudo systemctl start docker"
    exit 1
fi

echo -e "${GREEN}Building FreeBSD Docker image${NC}"
echo "Version: $FREEBSD_VERSION"
echo "Image: ${DOCKER_USER}/${IMAGE_NAME}:${FREEBSD_VERSION}"

# Build arguments
BUILD_ARGS=(
    --build-arg "FREEBSD_VERSION=${FREEBSD_VERSION}"
    --build-arg "BUILD_DATE=$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
    --build-arg "VCS_REF=$(git rev-parse --short HEAD 2>/dev/null || echo 'unknown')"
)

# Build the image
echo -e "${YELLOW}Building image...${NC}"
docker build "${BUILD_ARGS[@]}" \
    -t "${DOCKER_USER}/${IMAGE_NAME}:${FREEBSD_VERSION}" \
    -t "${DOCKER_USER}/${IMAGE_NAME}:latest" \
    .

if [ $? -eq 0 ]; then
    echo -e "${GREEN}Build successful!${NC}"
    
    # Show image info
    docker images "${DOCKER_USER}/${IMAGE_NAME}"
    
    # Push if requested
    if [ "$PUSH" == "push" ]; then
        echo -e "${YELLOW}Pushing to Docker Hub...${NC}"
        
        # Check if logged in
        if ! docker info 2>/dev/null | grep -q "Username"; then
            echo -e "${YELLOW}Not logged in to Docker Hub${NC}"
            echo "Run: docker login"
            exit 1
        fi
        
        docker push "${DOCKER_USER}/${IMAGE_NAME}:${FREEBSD_VERSION}"
        docker push "${DOCKER_USER}/${IMAGE_NAME}:latest"
        
        echo -e "${GREEN}Push complete!${NC}"
        echo "Image available at: https://hub.docker.com/r/${DOCKER_USER}/${IMAGE_NAME}"
    else
        echo ""
        echo "To push to Docker Hub:"
        echo "  $0 ${FREEBSD_VERSION} push"
    fi
    
    echo ""
    echo "To run the container:"
    echo "  docker run -it --rm --privileged ${DOCKER_USER}/${IMAGE_NAME}:${FREEBSD_VERSION}"
    echo ""
    echo "With SSH:"
    echo "  docker run -d --privileged -p 2222:22 ${DOCKER_USER}/${IMAGE_NAME}:${FREEBSD_VERSION}"
    echo "  ssh -p 2222 root@localhost"
else
    echo -e "${RED}Build failed!${NC}"
    exit 1
fi