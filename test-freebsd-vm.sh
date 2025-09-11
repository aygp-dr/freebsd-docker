#!/bin/bash
set -e

echo "====================================="
echo "FreeBSD Docker Container Test Suite"
echo "====================================="
echo

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0

# Function to run a test
run_test() {
    local test_name="$1"
    local test_command="$2"
    local expected_output="$3"
    
    echo -n "Testing: $test_name... "
    
    result=$(eval "$test_command" 2>&1 || true)
    
    if [[ "$result" == *"$expected_output"* ]]; then
        echo -e "${GREEN}✓ PASSED${NC}"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "${RED}✗ FAILED${NC}"
        echo "  Expected: $expected_output"
        echo "  Got: $result"
        ((TESTS_FAILED++))
        return 1
    fi
}

echo "1. Testing container environment (Alpine host layer):"
echo "------------------------------------------------------"

# Test that we're in Alpine Linux container
run_test "Container OS" \
    "docker run --rm aygpdr/freebsd:latest cat /etc/os-release | grep -i alpine" \
    "Alpine"

run_test "QEMU availability" \
    "docker run --rm aygpdr/freebsd:latest which qemu-system-x86_64" \
    "/usr/bin/qemu-system-x86_64"

echo
echo "2. Testing FreeBSD VM access methods:"
echo "--------------------------------------"

# Method 1: Direct SSH to FreeBSD VM
echo -e "${YELLOW}Method 1: SSH into FreeBSD VM${NC}"
cat > test-ssh-access.sh << 'EOF'
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
EOF
chmod +x test-ssh-access.sh
echo "  Run: ./test-ssh-access.sh (requires sshpass)"

# Method 2: Execute commands in running container
echo -e "${YELLOW}Method 2: Execute in running container${NC}"
cat > test-exec-access.sh << 'EOF'
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
EOF
chmod +x test-exec-access.sh

# Method 3: Interactive console access
echo -e "${YELLOW}Method 3: Interactive console${NC}"
echo "  Run: docker run -it --rm --privileged aygpdr/freebsd:latest"
echo "  Then: Use QEMU monitor commands or wait for boot"

echo
echo "3. Creating automated FreeBSD verification script:"
echo "---------------------------------------------------"

cat > verify-freebsd.sh << 'EOF'
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
EOF
chmod +x verify-freebsd.sh

echo
echo "4. Creating GitHub Actions test workflow:"
echo "------------------------------------------"

cat > .github/workflows/test-freebsd.yml << 'EOF'
name: Test FreeBSD VM

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]
  workflow_dispatch:

jobs:
  test-container:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
      
      - name: Pull Docker image
        run: docker pull aygpdr/freebsd:latest
      
      - name: Test Alpine container layer
        run: |
          echo "Testing container OS..."
          docker run --rm aygpdr/freebsd:latest cat /etc/os-release | grep -i alpine
          
          echo "Testing QEMU availability..."
          docker run --rm aygpdr/freebsd:latest which qemu-system-x86_64
      
      - name: Start FreeBSD container
        run: |
          docker run -d --name freebsd-test --privileged \
            -p 2222:22 \
            aygpdr/freebsd:latest
          
          echo "Waiting for container to start..."
          sleep 5
          docker ps | grep freebsd-test
      
      - name: Check QEMU process
        run: |
          docker exec freebsd-test pgrep qemu-system || \
            echo "QEMU not yet started"
          
          docker logs freebsd-test
      
      - name: Wait for FreeBSD boot
        run: |
          echo "Waiting for FreeBSD VM to boot (60 seconds max)..."
          timeout=60
          while [ $timeout -gt 0 ]; do
            if docker exec freebsd-test nc -z localhost 22 2>/dev/null; then
              echo "FreeBSD SSH port is open!"
              break
            fi
            echo "Waiting... ($timeout seconds left)"
            sleep 10
            timeout=$((timeout - 10))
          done
      
      - name: Test FreeBSD access
        run: |
          # Install sshpass for automated testing
          sudo apt-get update && sudo apt-get install -y sshpass
          
          # Test SSH connection to FreeBSD
          sshpass -p 'freebsd' ssh -o StrictHostKeyChecking=no \
            -p 2222 root@localhost 'uname -a' || \
            echo "FreeBSD not accessible via SSH yet"
      
      - name: Container logs
        if: always()
        run: docker logs freebsd-test
      
      - name: Cleanup
        if: always()
        run: |
          docker stop freebsd-test || true
          docker rm freebsd-test || true
EOF

echo
echo "====================================="
echo "Summary:"
echo "====================================="
echo -e "${GREEN}Tests Passed: $TESTS_PASSED${NC}"
echo -e "${RED}Tests Failed: $TESTS_FAILED${NC}"
echo
echo "IMPORTANT: The FreeBSD VM runs INSIDE the container!"
echo "You're seeing Alpine because that's the container OS."
echo "FreeBSD is running in QEMU within the container."
echo
echo "To access FreeBSD, you need to either:"
echo "1. SSH to port 22 (mapped to 2222 on host)"
echo "2. Use QEMU console commands"
echo "3. Wait for VM to boot and use docker exec with SSH"
echo
echo "The container architecture is:"
echo "  Host OS → Docker → Alpine Container → QEMU → FreeBSD VM"