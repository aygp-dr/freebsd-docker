#!/bin/bash
set -e

echo "=========================================="
echo "FreeBSD Docker Test on macOS"
echo "=========================================="
echo

# Check if Docker is running
if ! docker info >/dev/null 2>&1; then
    echo "❌ Docker is not running!"
    echo "Please start Docker Desktop first:"
    echo "  1. Open Docker Desktop from Applications"
    echo "  2. Wait for Docker to start (icon in menu bar)"
    echo "  3. Run this script again"
    exit 1
fi

echo "✓ Docker is running"
echo

# Pull the latest image
echo "Pulling latest FreeBSD image..."
docker pull aygpdr/freebsd:latest

# Check image size
echo
echo "Image details:"
docker images aygpdr/freebsd:latest

# Start the container
echo
echo "Starting FreeBSD container..."
docker run -d --name freebsd-test --privileged -p 2222:22 aygpdr/freebsd:latest

echo "Waiting 60 seconds for FreeBSD to boot..."
sleep 60

# Test SSH access
echo
echo "Testing FreeBSD access..."
if command -v sshpass >/dev/null 2>&1; then
    sshpass -p 'freebsd' ssh -o StrictHostKeyChecking=no -p 2222 root@localhost 'uname -a'
else
    echo "To test FreeBSD, run:"
    echo "  ssh -p 2222 root@localhost"
    echo "  Password: freebsd"
    echo "  Then run: uname -a"
fi

echo
echo "Container 'freebsd-test' is running."
echo "Stop with: docker stop freebsd-test && docker rm freebsd-test"