#!/bin/bash
set -e

# Configuration
FREEBSD_VERSION="${FREEBSD_VERSION:-14.2-RELEASE}"
ISO_CACHE_DIR="${ISO_CACHE_DIR:-/var/cache/freebsd-iso}"
MEMORY="${MEMORY:-2G}"
CPUS="${CPUS:-2}"
DISK_IMAGE="/freebsd/disk.qcow2"

# Determine architecture
ARCH="${ARCH:-amd64}"

# ISO details
ISO_FILENAME="FreeBSD-${FREEBSD_VERSION}-${ARCH}-disc1.iso"
ISO_PATH="${ISO_CACHE_DIR}/${ISO_FILENAME}"
ISO_URL="https://download.freebsd.org/ftp/releases/${ARCH}/${ARCH}/ISO-IMAGES/${FREEBSD_VERSION}/${ISO_FILENAME}"

# Mirror list for fallback (can be extended)
MIRRORS=(
    "https://download.freebsd.org"
)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Download ISO with progress and resume support
download_iso() {
    local url="$1"
    local output="$2"
    
    log_info "Downloading FreeBSD ${FREEBSD_VERSION} ISO (1.3GB)..."
    echo "   URL: ${url}"
    echo "   Destination: ${output}"
    echo ""
    
    # Create cache directory if it doesn't exist
    mkdir -p "$(dirname "$output")"
    
    # Download with resume support and progress bar
    if curl -L -C - \
            --progress-bar \
            --retry 3 \
            --retry-delay 5 \
            --connect-timeout 30 \
            --max-time 3600 \
            -o "$output" \
            "$url"; then
        return 0
    else
        return 1
    fi
}

# Verify ISO integrity (basic size check)
verify_iso() {
    local iso_file="$1"
    local min_size=$((1000 * 1024 * 1024))  # 1GB minimum
    
    if [ ! -f "$iso_file" ]; then
        return 1
    fi
    
    local file_size=$(stat -f%z "$iso_file" 2>/dev/null || stat -c%s "$iso_file" 2>/dev/null)
    
    if [ "$file_size" -lt "$min_size" ]; then
        log_error "ISO file too small (${file_size} bytes), expected > 1GB"
        return 1
    fi
    
    return 0
}

# Check if ISO needs to be downloaded
check_iso() {
    if [ -f "$ISO_PATH" ]; then
        log_info "Found cached ISO at ${ISO_PATH}"
        
        if verify_iso "$ISO_PATH"; then
            log_success "Using cached FreeBSD ${FREEBSD_VERSION} ISO"
            return 0
        else
            log_warning "Cached ISO appears corrupt, re-downloading..."
            rm -f "$ISO_PATH"
        fi
    fi
    
    # Try downloading from mirrors
    for mirror in "${MIRRORS[@]}"; do
        local mirror_url="${mirror}/releases/${ARCH}/${ARCH}/ISO-IMAGES/${FREEBSD_VERSION}/${ISO_FILENAME}"
        
        log_info "Trying mirror: ${mirror}"
        
        if download_iso "$mirror_url" "$ISO_PATH"; then
            if verify_iso "$ISO_PATH"; then
                log_success "Successfully downloaded FreeBSD ISO"
                
                # Show cache info
                local iso_size=$(du -h "$ISO_PATH" | cut -f1)
                echo ""
                log_success "ISO cached for future use:"
                echo "   Path: ${ISO_PATH}"
                echo "   Size: ${iso_size}"
                echo "   Version: ${FREEBSD_VERSION}"
                echo ""
                echo "   💡 TIP: Mount ${ISO_CACHE_DIR} as a volume to share ISO across containers:"
                echo "      docker run -v freebsd-iso:${ISO_CACHE_DIR} ..."
                echo ""
                
                return 0
            else
                rm -f "$ISO_PATH"
            fi
        fi
    done
    
    log_error "Failed to download FreeBSD ISO from all mirrors"
    return 1
}

# Initialize disk if needed
init_disk() {
    if [ ! -f "$DISK_IMAGE" ]; then
        log_info "Creating disk image (${DISK_SIZE:-20G})..."
        qemu-img create -f qcow2 "$DISK_IMAGE" "${DISK_SIZE:-20G}"
        log_success "Disk image created"
    fi
}

# Start QEMU
start_qemu() {
    local qemu_args=(
        -m "$MEMORY"
        -smp "$CPUS"
        -drive "file=${DISK_IMAGE},format=qcow2,if=virtio"
        -device virtio-net,netdev=net0
        -netdev user,id=net0,hostfwd=tcp::22-:22
    )
    
    # Add ISO if available
    if [ -f "$ISO_PATH" ]; then
        qemu_args+=(-cdrom "$ISO_PATH")
        
        # Boot from ISO if disk is empty
        if ! qemu-img info "$DISK_IMAGE" | grep -q "disk size: [1-9]"; then
            qemu_args+=(-boot d)
        fi
    fi
    
    # Add VNC if requested
    if [ "${ENABLE_VNC:-false}" = "true" ]; then
        qemu_args+=(-vnc :0)
        log_info "VNC enabled on port 5900"
    fi
    
    # Add serial console
    if [ "${ENABLE_CONSOLE:-true}" = "true" ]; then
        qemu_args+=(-nographic)
    fi
    
    # Check for KVM acceleration
    if [ -e /dev/kvm ] && [ -r /dev/kvm ] && [ -w /dev/kvm ]; then
        qemu_args+=(-enable-kvm)
        log_success "KVM acceleration enabled"
    else
        log_warning "Running without KVM acceleration"
    fi
    
    # Additional QEMU arguments from environment
    if [ -n "$QEMU_EXTRA_ARGS" ]; then
        qemu_args+=($QEMU_EXTRA_ARGS)
    fi
    
    log_info "Starting FreeBSD VM"
    echo "  Memory: $MEMORY"
    echo "  CPUs: $CPUS"
    echo "  Network: user mode, SSH on port 22"
    echo ""
    
    exec qemu-system-x86_64 "${qemu_args[@]}"
}

# Main execution
main() {
    case "${1:-start}" in
        start)
            log_info "FreeBSD Docker Container (Lightweight Edition)"
            echo "========================================="
            echo ""
            
            # Check and download ISO if needed
            if ! check_iso; then
                log_error "Cannot proceed without FreeBSD ISO"
                exit 1
            fi
            
            # Initialize disk
            init_disk
            
            # Start QEMU
            start_qemu
            ;;
            
        download-iso)
            # Just download the ISO and exit
            if check_iso; then
                log_success "ISO ready at ${ISO_PATH}"
            else
                exit 1
            fi
            ;;
            
        shell)
            # Drop to shell for debugging
            log_info "Dropping to shell..."
            exec /bin/bash
            ;;
            
        *)
            log_error "Unknown command: $1"
            echo "Usage: $0 {start|download-iso|shell}"
            exit 1
            ;;
    esac
}

# Run main function
main "$@"