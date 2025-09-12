#!/bin/bash
# Start container
docker run -d --name freebsd-test --privileged aygpdr/freebsd:latest
echo "Waiting for FreeBSD VM to boot..."
sleep 30

# Connect to FreeBSD console via QEMU monitor
docker exec freebsd-test sh -c 'echo "info status" | nc localhost 1234' || true

# Send commands to FreeBSD via expect or screen
docker exec freebsd-test sh -c 'echo "uname -a" | nc localhost 22' || true

# Cleanup
docker stop freebsd-test && docker rm freebsd-test
