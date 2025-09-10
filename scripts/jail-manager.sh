#!/bin/sh
# FreeBSD Jail Management Script
# Manages jails within the FreeBSD VM

set -e

JAIL_ROOT="${JAIL_ROOT:-/usr/local/jails}"
JAIL_DATASET="${JAIL_DATASET:-zroot/jails}"
BASE_RELEASE="${BASE_RELEASE:-14.0-RELEASE}"

# Ensure running on FreeBSD
if [ "$(uname -s)" != "FreeBSD" ]; then
    echo "Error: This script must run on FreeBSD"
    exit 1
fi

create_jail() {
    JAIL_NAME="$1"
    [ -z "$JAIL_NAME" ] && { echo "Usage: $0 create <jail_name>"; exit 1; }
    
    JAIL_PATH="${JAIL_ROOT}/${JAIL_NAME}"
    
    echo "Creating jail: $JAIL_NAME"
    
    # Create jail directory
    mkdir -p "$JAIL_PATH"
    
    # If ZFS is available, create dataset
    if zfs list "$JAIL_DATASET" >/dev/null 2>&1; then
        echo "Creating ZFS dataset for jail"
        zfs create -o mountpoint="$JAIL_PATH" "${JAIL_DATASET}/${JAIL_NAME}"
        zfs set compression=lz4 "${JAIL_DATASET}/${JAIL_NAME}"
    fi
    
    # Extract base system
    if [ ! -f "/tmp/base.txz" ]; then
        echo "Downloading FreeBSD base system"
        fetch -o /tmp/base.txz "https://download.freebsd.org/releases/amd64/${BASE_RELEASE}/base.txz"
    fi
    
    echo "Extracting base system to jail"
    tar -xf /tmp/base.txz -C "$JAIL_PATH"
    
    # Copy resolv.conf
    cp /etc/resolv.conf "${JAIL_PATH}/etc/resolv.conf"
    
    # Create jail configuration
    cat >> /etc/jail.conf <<EOF

${JAIL_NAME} {
    host.hostname = "${JAIL_NAME}.local";
    path = "${JAIL_PATH}";
    ip4.addr = "lo1|10.1.1.${RANDOM}/32";
    mount.devfs;
    exec.start = "/bin/sh /etc/rc";
    exec.stop = "/bin/sh /etc/rc.shutdown";
    exec.clean;
    allow.raw_sockets;
    allow.sysvipc;
}
EOF
    
    # Create lo1 interface if it doesn't exist
    ifconfig lo1 create 2>/dev/null || true
    
    echo "Jail $JAIL_NAME created successfully"
}

start_jail() {
    JAIL_NAME="$1"
    [ -z "$JAIL_NAME" ] && { echo "Usage: $0 start <jail_name>"; exit 1; }
    
    echo "Starting jail: $JAIL_NAME"
    jail -c "$JAIL_NAME"
    jls -j "$JAIL_NAME"
}

stop_jail() {
    JAIL_NAME="$1"
    [ -z "$JAIL_NAME" ] && { echo "Usage: $0 stop <jail_name>"; exit 1; }
    
    echo "Stopping jail: $JAIL_NAME"
    jail -r "$JAIL_NAME"
}

list_jails() {
    echo "Active jails:"
    jls -h name host.hostname path ip4.addr
    
    echo ""
    echo "Configured jails:"
    grep '^[a-zA-Z]' /etc/jail.conf 2>/dev/null | grep '{' | sed 's/ {//' || echo "None"
}

destroy_jail() {
    JAIL_NAME="$1"
    [ -z "$JAIL_NAME" ] && { echo "Usage: $0 destroy <jail_name>"; exit 1; }
    
    # Stop jail if running
    if jls -j "$JAIL_NAME" >/dev/null 2>&1; then
        stop_jail "$JAIL_NAME"
    fi
    
    JAIL_PATH="${JAIL_ROOT}/${JAIL_NAME}"
    
    # Remove ZFS dataset if exists
    if zfs list "${JAIL_DATASET}/${JAIL_NAME}" >/dev/null 2>&1; then
        echo "Destroying ZFS dataset"
        zfs destroy -r "${JAIL_DATASET}/${JAIL_NAME}"
    else
        # Remove directory
        echo "Removing jail directory"
        rm -rf "$JAIL_PATH"
    fi
    
    # Remove from jail.conf
    sed -i.bak "/^${JAIL_NAME} {/,/^}/d" /etc/jail.conf
    
    echo "Jail $JAIL_NAME destroyed"
}

exec_jail() {
    JAIL_NAME="$1"
    shift
    [ -z "$JAIL_NAME" ] && { echo "Usage: $0 exec <jail_name> <command>"; exit 1; }
    
    jexec "$JAIL_NAME" "$@"
}

snapshot_jail() {
    JAIL_NAME="$1"
    SNAP_NAME="${2:-$(date +%Y%m%d_%H%M%S)}"
    [ -z "$JAIL_NAME" ] && { echo "Usage: $0 snapshot <jail_name> [snapshot_name]"; exit 1; }
    
    if zfs list "${JAIL_DATASET}/${JAIL_NAME}" >/dev/null 2>&1; then
        echo "Creating snapshot: ${JAIL_NAME}@${SNAP_NAME}"
        zfs snapshot "${JAIL_DATASET}/${JAIL_NAME}@${SNAP_NAME}"
        zfs list -t snapshot -r "${JAIL_DATASET}/${JAIL_NAME}"
    else
        echo "Error: Jail is not on ZFS"
        exit 1
    fi
}

clone_jail() {
    SOURCE_JAIL="$1"
    NEW_JAIL="$2"
    [ -z "$SOURCE_JAIL" ] || [ -z "$NEW_JAIL" ] && { 
        echo "Usage: $0 clone <source_jail> <new_jail>"
        exit 1
    }
    
    if zfs list "${JAIL_DATASET}/${SOURCE_JAIL}" >/dev/null 2>&1; then
        # Create snapshot if doesn't exist
        SNAP_NAME="clone_$(date +%s)"
        zfs snapshot "${JAIL_DATASET}/${SOURCE_JAIL}@${SNAP_NAME}"
        
        # Clone from snapshot
        echo "Cloning $SOURCE_JAIL to $NEW_JAIL"
        zfs clone "${JAIL_DATASET}/${SOURCE_JAIL}@${SNAP_NAME}" "${JAIL_DATASET}/${NEW_JAIL}"
        
        # Update jail.conf
        grep -A 10 "^${SOURCE_JAIL} {" /etc/jail.conf | \
            sed "s/${SOURCE_JAIL}/${NEW_JAIL}/g" >> /etc/jail.conf
        
        echo "Jail cloned successfully"
    else
        echo "Error: Source jail is not on ZFS"
        exit 1
    fi
}

case "${1:-help}" in
    create)
        shift
        create_jail "$@"
        ;;
    start)
        shift
        start_jail "$@"
        ;;
    stop)
        shift
        stop_jail "$@"
        ;;
    restart)
        shift
        stop_jail "$@"
        start_jail "$@"
        ;;
    destroy)
        shift
        destroy_jail "$@"
        ;;
    list)
        list_jails
        ;;
    exec)
        shift
        exec_jail "$@"
        ;;
    snapshot)
        shift
        snapshot_jail "$@"
        ;;
    clone)
        shift
        clone_jail "$@"
        ;;
    help|*)
        cat <<EOF
FreeBSD Jail Manager

Usage: $0 <command> [options]

Commands:
  create <name>           Create a new jail
  start <name>            Start a jail
  stop <name>             Stop a jail
  restart <name>          Restart a jail
  destroy <name>          Destroy a jail
  list                    List all jails
  exec <name> <cmd>       Execute command in jail
  snapshot <name> [snap]  Create jail snapshot (ZFS only)
  clone <src> <dst>       Clone a jail (ZFS only)
  help                    Show this help

Environment Variables:
  JAIL_ROOT               Root directory for jails (default: /usr/local/jails)
  JAIL_DATASET            ZFS dataset for jails (default: zroot/jails)
  BASE_RELEASE            FreeBSD release (default: 14.0-RELEASE)

Examples:
  $0 create web
  $0 start web
  $0 exec web pkg install nginx
  $0 snapshot web backup1
  $0 clone web web-dev
EOF
        ;;
esac