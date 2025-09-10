#!/bin/bash
pgrep -f "qemu-system-x86_64" > /dev/null || exit 1
nc -z localhost "${SSH_PORT:-22}" 2>/dev/null || exit 1
exit 0
