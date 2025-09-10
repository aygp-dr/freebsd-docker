#!/bin/bash
set -e

MEMORY="${MEMORY:-1G}"
CPUS="${CPUS:-2}"
SSH_PORT="${SSH_PORT:-22}"
VNC_PORT="${VNC_PORT:-5900}"
ENABLE_VNC="${ENABLE_VNC:-false}"
ENABLE_BRIDGE="${ENABLE_BRIDGE:-false}"
DISK_SIZE="${DISK_SIZE:-10G}"
NETWORK_MODE="${NETWORK_MODE:-user}"

# Create disk if it doesn't exist
if [ ! -f /freebsd/disk.qcow2 ]; then
    echo "Creating disk image (${DISK_SIZE})"
    qemu-img create -f qcow2 /freebsd/disk.qcow2 "$DISK_SIZE"
fi

# Base QEMU options
QEMU_OPTS=(
    -m "${MEMORY}"
    -smp "${CPUS}"
    -drive "file=/freebsd/disk.qcow2,format=qcow2,if=virtio"
    -nographic
)

# Configure networking
case "$NETWORK_MODE" in
    user)
        QEMU_OPTS+=(
            -netdev "user,id=net0,hostfwd=tcp::${SSH_PORT}-:22"
            -device "virtio-net,netdev=net0"
        )
        ;;
    bridge)
        if [ "$ENABLE_BRIDGE" = "true" ]; then
            /scripts/network-setup.sh setup
            QEMU_OPTS+=(
                -netdev "tap,id=net0,ifname=tap0,script=no,downscript=no"
                -device "virtio-net,netdev=net0,mac=52:54:00:12:34:56"
            )
        fi
        ;;
    none)
        ;;
esac

# Add VNC if enabled
if [ "$ENABLE_VNC" = "true" ]; then
    QEMU_OPTS+=(-vnc ":0")
    echo "VNC enabled on port $VNC_PORT"
fi

# Add KVM if available
if [ -e /dev/kvm ]; then
    QEMU_OPTS+=(-enable-kvm -cpu host)
    echo "KVM acceleration enabled"
else
    QEMU_OPTS+=(-cpu qemu64)
    echo "Running without KVM acceleration"
fi

# Add additional disks for ZFS if requested
if [ -n "$ZFS_DISK" ]; then
    if [ ! -f "/freebsd/zfs-${ZFS_DISK}.qcow2" ]; then
        qemu-img create -f qcow2 "/freebsd/zfs-${ZFS_DISK}.qcow2" "$ZFS_DISK"
    fi
    QEMU_OPTS+=(-drive "file=/freebsd/zfs-${ZFS_DISK}.qcow2,format=qcow2,if=virtio")
    echo "Added ZFS disk: $ZFS_DISK"
fi

cleanup() {
    echo "Shutting down FreeBSD VM..."
    [ "$ENABLE_BRIDGE" = "true" ] && /scripts/network-setup.sh teardown
    exit 0
}

trap cleanup SIGINT SIGTERM

case "$1" in
    start)
        echo "Starting FreeBSD VM"
        echo "  Memory: $MEMORY"
        echo "  CPUs: $CPUS"
        echo "  Network: $NETWORK_MODE"
        echo "  SSH Port: $SSH_PORT"
        exec qemu-system-x86_64 "${QEMU_OPTS[@]}"
        ;;
    ssh)
        echo "Connecting to FreeBSD VM..."
        ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
            -p "${SSH_PORT}" root@localhost
        ;;
    console)
        echo "Attaching to FreeBSD console..."
        socat - TCP:localhost:4444
        ;;
    jail)
        shift
        ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
            -p "${SSH_PORT}" root@localhost "/scripts/jail-manager.sh $*"
        ;;
    zfs)
        shift
        ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
            -p "${SSH_PORT}" root@localhost "/scripts/zfs-setup.sh $*"
        ;;
    *)
        exec "$@"
        ;;
esac
