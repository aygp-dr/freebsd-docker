#!/bin/bash
set -e

echo "Testing FreeBSD container startup (10 iterations)..."

for i in {1..10}; do
    echo -n "Test $i: "
    START=$(date +%s)
    
    # Run container and check QEMU version
    docker run --rm --platform linux/amd64 \
        --entrypoint /bin/sh \
        aygpdr/freebsd:latest \
        -c "qemu-system-x86_64 --version | head -1" > /dev/null 2>&1
    
    END=$(date +%s)
    DURATION=$((END - START))
    echo "${DURATION}s"
done

echo "All tests completed successfully"