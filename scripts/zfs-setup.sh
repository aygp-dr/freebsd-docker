#!/bin/sh
# FreeBSD ZFS Configuration for Docker Container
# Sets up ZFS pools and datasets within the VM

set -e

POOL_NAME="${POOL_NAME:-zroot}"
POOL_DEVICE="${POOL_DEVICE:-/dev/vtbd1}"
POOL_SIZE="${POOL_SIZE:-5G}"

# Check if running on FreeBSD
if [ "$(uname -s)" != "FreeBSD" ]; then
    echo "Error: This script must run on FreeBSD"
    exit 1
fi

check_zfs() {
    if ! kldstat | grep -q zfs; then
        echo "Loading ZFS kernel module"
        kldload zfs
    fi
    
    if ! command -v zpool >/dev/null 2>&1; then
        echo "Error: ZFS tools not found"
        exit 1
    fi
}

create_pool() {
    echo "Creating ZFS pool: $POOL_NAME"
    
    # Check if pool already exists
    if zpool list "$POOL_NAME" >/dev/null 2>&1; then
        echo "Pool $POOL_NAME already exists"
        return 0
    fi
    
    # Create pool device if it doesn't exist
    if [ ! -e "$POOL_DEVICE" ]; then
        echo "Creating virtual disk for ZFS pool"
        truncate -s "$POOL_SIZE" "$POOL_DEVICE"
    fi
    
    # Create the pool
    zpool create -f \
        -O compression=lz4 \
        -O atime=off \
        -O mountpoint=none \
        "$POOL_NAME" "$POOL_DEVICE"
    
    echo "ZFS pool created successfully"
}

create_datasets() {
    echo "Creating ZFS datasets"
    
    # Root dataset for jails
    if ! zfs list "${POOL_NAME}/jails" >/dev/null 2>&1; then
        zfs create -o mountpoint=/usr/local/jails "${POOL_NAME}/jails"
        zfs set compression=lz4 "${POOL_NAME}/jails"
        echo "Created ${POOL_NAME}/jails"
    fi
    
    # Dataset for Docker volumes
    if ! zfs list "${POOL_NAME}/docker" >/dev/null 2>&1; then
        zfs create -o mountpoint=/var/lib/docker "${POOL_NAME}/docker"
        zfs set compression=lz4 "${POOL_NAME}/docker"
        echo "Created ${POOL_NAME}/docker"
    fi
    
    # Dataset for user data
    if ! zfs list "${POOL_NAME}/data" >/dev/null 2>&1; then
        zfs create -o mountpoint=/data "${POOL_NAME}/data"
        zfs set compression=lz4 "${POOL_NAME}/data"
        zfs set dedup=off "${POOL_NAME}/data"
        echo "Created ${POOL_NAME}/data"
    fi
    
    # Dataset for backups
    if ! zfs list "${POOL_NAME}/backups" >/dev/null 2>&1; then
        zfs create -o mountpoint=/backups "${POOL_NAME}/backups"
        zfs set compression=gzip-9 "${POOL_NAME}/backups"
        echo "Created ${POOL_NAME}/backups"
    fi
}

setup_snapshots() {
    echo "Setting up automatic snapshots"
    
    # Create snapshot script
    cat > /usr/local/bin/zfs-auto-snapshot <<'EOF'
#!/bin/sh
# Auto-snapshot script for ZFS datasets

DATASETS="zroot/jails zroot/data"
KEEP_HOURLY=24
KEEP_DAILY=7
KEEP_WEEKLY=4
KEEP_MONTHLY=12

for ds in $DATASETS; do
    # Hourly snapshots
    zfs snapshot "${ds}@auto-$(date +%Y%m%d-%H%M%S)"
    
    # Clean old snapshots
    zfs list -t snapshot -o name -s creation -r "$ds" | \
        grep '@auto-' | \
        head -n -${KEEP_HOURLY} | \
        xargs -n1 zfs destroy 2>/dev/null || true
done
EOF
    
    chmod +x /usr/local/bin/zfs-auto-snapshot
    
    # Add to crontab
    if ! crontab -l 2>/dev/null | grep -q zfs-auto-snapshot; then
        (crontab -l 2>/dev/null; echo "0 * * * * /usr/local/bin/zfs-auto-snapshot") | crontab -
        echo "Added automatic snapshot to crontab"
    fi
}

setup_scrub() {
    echo "Setting up ZFS scrub schedule"
    
    # Create scrub script
    cat > /usr/local/bin/zfs-scrub <<EOF
#!/bin/sh
# Weekly ZFS scrub
zpool scrub $POOL_NAME
EOF
    
    chmod +x /usr/local/bin/zfs-scrub
    
    # Add weekly scrub to crontab
    if ! crontab -l 2>/dev/null | grep -q zfs-scrub; then
        (crontab -l 2>/dev/null; echo "0 2 * * 0 /usr/local/bin/zfs-scrub") | crontab -
        echo "Added weekly scrub to crontab"
    fi
}

optimize_zfs() {
    echo "Optimizing ZFS settings"
    
    # ARC settings (limit to 512MB for container environment)
    sysctl vfs.zfs.arc_max=536870912
    echo 'vfs.zfs.arc_max="536870912"' >> /etc/sysctl.conf
    
    # Prefetch settings
    sysctl vfs.zfs.prefetch_disable=0
    echo 'vfs.zfs.prefetch_disable="0"' >> /etc/sysctl.conf
    
    # Transaction group timeout
    sysctl vfs.zfs.txg.timeout=5
    echo 'vfs.zfs.txg.timeout="5"' >> /etc/sysctl.conf
}

status() {
    echo "=== ZFS Status ==="
    echo ""
    echo "Pools:"
    zpool list
    echo ""
    echo "Pool Status:"
    zpool status -v
    echo ""
    echo "Datasets:"
    zfs list -t filesystem
    echo ""
    echo "Snapshots:"
    zfs list -t snapshot
}

destroy_pool() {
    echo "WARNING: This will destroy all data in pool $POOL_NAME"
    echo "Type 'yes' to confirm:"
    read -r confirm
    
    if [ "$confirm" = "yes" ]; then
        # Destroy all datasets
        zfs destroy -r "$POOL_NAME" 2>/dev/null || true
        
        # Destroy pool
        zpool destroy "$POOL_NAME"
        
        # Remove device
        rm -f "$POOL_DEVICE"
        
        echo "Pool destroyed"
    else
        echo "Cancelled"
    fi
}

backup() {
    DATASET="${1:-${POOL_NAME}/data}"
    BACKUP_FILE="${2:-/backups/zfs-backup-$(date +%Y%m%d-%H%M%S).zfs}"
    
    echo "Backing up $DATASET to $BACKUP_FILE"
    
    # Create snapshot
    SNAP_NAME="backup-$(date +%Y%m%d-%H%M%S)"
    zfs snapshot "${DATASET}@${SNAP_NAME}"
    
    # Send snapshot to file
    zfs send "${DATASET}@${SNAP_NAME}" | gzip > "$BACKUP_FILE"
    
    echo "Backup completed: $BACKUP_FILE"
}

restore() {
    BACKUP_FILE="$1"
    DATASET="${2:-${POOL_NAME}/restored}"
    
    [ -z "$BACKUP_FILE" ] && { echo "Usage: $0 restore <backup_file> [dataset]"; exit 1; }
    
    echo "Restoring from $BACKUP_FILE to $DATASET"
    
    gunzip -c "$BACKUP_FILE" | zfs receive -F "$DATASET"
    
    echo "Restore completed"
}

case "${1:-help}" in
    init)
        check_zfs
        create_pool
        create_datasets
        setup_snapshots
        setup_scrub
        optimize_zfs
        status
        echo ""
        echo "ZFS setup complete!"
        ;;
    status)
        status
        ;;
    backup)
        shift
        backup "$@"
        ;;
    restore)
        shift
        restore "$@"
        ;;
    destroy)
        destroy_pool
        ;;
    help|*)
        cat <<EOF
FreeBSD ZFS Setup for Docker

Usage: $0 <command> [options]

Commands:
  init              Initialize ZFS pool and datasets
  status            Show ZFS status
  backup [dataset]  Backup a dataset
  restore <file>    Restore from backup
  destroy           Destroy pool (WARNING: destroys all data)
  help              Show this help

Environment Variables:
  POOL_NAME         ZFS pool name (default: zroot)
  POOL_DEVICE       Device for ZFS pool (default: /dev/vtbd1)
  POOL_SIZE         Size of virtual device (default: 5G)

Default Datasets Created:
  ${POOL_NAME}/jails    - FreeBSD jails
  ${POOL_NAME}/docker   - Docker storage
  ${POOL_NAME}/data     - User data
  ${POOL_NAME}/backups  - Backup storage

Examples:
  $0 init
  $0 status
  $0 backup zroot/data /backups/data.zfs
  $0 restore /backups/data.zfs zroot/data-restored
EOF
        ;;
esac