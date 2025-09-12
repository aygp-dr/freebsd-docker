#!/bin/bash
# Start container with SSH exposed
docker run -d --name freebsd-test --privileged -p 2222:22 aygpdr/freebsd:latest
echo "Waiting for FreeBSD VM to boot (30 seconds)..."
sleep 30

# Test SSH connection and run FreeBSD commands
echo "Testing FreeBSD via SSH..."
sshpass -p 'freebsd' ssh -o StrictHostKeyChecking=no -p 2222 root@localhost "uname -a" || echo "SSH not ready"

# Cleanup
docker stop freebsd-test && docker rm freebsd-test
