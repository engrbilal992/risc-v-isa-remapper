#!/bin/bash
# Alpine Linux RISC-V Boot Script — Patched QEMU 8.2
source "$(dirname "$(readlink -f "$0")")/../config.sh"
source "$(dirname "$(readlink -f "$0")")/../lib/generate_mapping.sh"

BOOT_SEED=$(generate_mapping_random)
echo "[ISA] Mapping active (seed=$BOOT_SEED)"

$QEMU_SYSTEM \
    -machine virt \
    -nographic \
    -m 512M \
    -bios $QEMU_BIOS \
    -kernel "$ALPINE_KERNEL" \
    -initrd "$ALPINE_INITRD" \
    -drive file="$ALPINE_IMG",format=raw,id=hd0,if=none \
    -device virtio-blk-device,drive=hd0 \
    -append "root=/dev/vda rw console=ttyS0" \
    -netdev user,id=net0 \
    -device virtio-net-device,netdev=net0
