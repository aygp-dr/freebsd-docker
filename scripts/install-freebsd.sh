#!/bin/bash
set -e

echo "Automated FreeBSD installation..."

cat > /tmp/installerconfig << 'EOF'
PARTITIONS="AUTO"
echo 'freebsd' | pw usermod root -h 0
echo 'sshd_enable="YES"' >> /etc/rc.conf
echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config
echo 'ifconfig_vtnet0="DHCP"' >> /etc/rc.conf
env ASSUME_ALWAYS_YES=YES pkg bootstrap
pkg install -y bash git python3
EOF

qemu-system-x86_64 \
    -m 2G \
    -drive file=/freebsd/disk.qcow2,format=qcow2,if=virtio \
    -cdrom /freebsd/freebsd.iso \
    -boot d \
    -nographic \
    -no-reboot \
    < /tmp/installerconfig || true

rm -f /freebsd/freebsd.iso
