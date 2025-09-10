#!/bin/bash
set -e

MEMORY="${MEMORY:-1G}"
CPUS="${CPUS:-2}"
SSH_PORT="${SSH_PORT:-22}"

QEMU_OPTS=(
    -m "${MEMORY}"
    -smp "${CPUS}"
    -drive "file=/freebsd/disk.qcow2,format=qcow2,if=virtio"
    -netdev "user,id=net0,hostfwd=tcp::${SSH_PORT}-:22"
    -device "virtio-net,netdev=net0"
    -nographic
)

# Add KVM if available
[ -e /dev/kvm ] && QEMU_OPTS+=(-enable-kvm -cpu host) || QEMU_OPTS+=(-cpu qemu64)

case "$1" in
    start)
        echo "Starting FreeBSD VM (Memory: $MEMORY, CPUs: $CPUS)"
        exec qemu-system-x86_64 "${QEMU_OPTS[@]}"
        ;;
    ssh)
        ssh -o StrictHostKeyChecking=no -p "${SSH_PORT}" root@localhost
        ;;
    *)
        exec "$@"
        ;;
esac
