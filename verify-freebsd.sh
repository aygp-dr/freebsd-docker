#!/bin/sh
# This script runs INSIDE the container to verify FreeBSD is running

echo "Checking if FreeBSD VM is running..."

# Check if QEMU process is running
if pgrep qemu-system > /dev/null; then
    echo "✓ QEMU process found"
else
    echo "✗ QEMU process not found"
    exit 1
fi

# Check if we can connect to FreeBSD SSH (after boot)
timeout=60
while [ $timeout -gt 0 ]; do
    if nc -z localhost 22 2>/dev/null; then
        echo "✓ FreeBSD SSH port is open"
        break
    fi
    echo "  Waiting for FreeBSD to boot... ($timeout seconds left)"
    sleep 5
    timeout=$((timeout - 5))
done

if [ $timeout -le 0 ]; then
    echo "✗ FreeBSD SSH port not responding after 60 seconds"
    exit 1
fi

# Try to get FreeBSD version via SSH
echo "Attempting to connect to FreeBSD VM..."
echo "  Note: Default password is 'freebsd'"

# Create expect script for automated SSH test
cat > /tmp/test-ssh.exp << 'EXPECT'
#!/usr/bin/expect -f
set timeout 10
spawn ssh -o StrictHostKeyChecking=no root@localhost
expect "password:"
send "freebsd\r"
expect "root@"
send "uname -a\r"
expect "FreeBSD"
send "exit\r"
expect eof
EXPECT

if command -v expect > /dev/null; then
    expect /tmp/test-ssh.exp
else
    echo "  Install expect for automated SSH testing"
    echo "  Manual test: ssh root@localhost (password: freebsd)"
fi
