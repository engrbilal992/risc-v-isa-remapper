#!/bin/bash
# Alpine Linux RISC-V — Integration Boot Script
source "$(dirname "$(readlink -f "$0")")/../config.sh"

ALPINE_DIR="$(dirname "$(readlink -f "$0")")"

# Find system QEMU — check multiple locations
QEMU_SYS=""
for candidate in \
    "$BASE_DIR/../phase1/qemu-8.2.0/build/qemu-system-riscv64" \
    "$HOME/risc-v-isa-remapper/phase1/qemu-8.2.0/build/qemu-system-riscv64" \
    "$(which qemu-system-riscv64 2>/dev/null)"; do
    [ -f "$candidate" ] && QEMU_SYS="$candidate" && break
done

QEMU_BIOS=""
for bcandidate in \
    "$BASE_DIR/../phase1/qemu-8.2.0/pc-bios/opensbi-riscv64-generic-fw_dynamic.bin" \
    "$HOME/risc-v-isa-remapper/phase1/qemu-8.2.0/pc-bios/opensbi-riscv64-generic-fw_dynamic.bin"; do
    [ -f "$bcandidate" ] && QEMU_BIOS="$bcandidate" && break
done

echo "████████████████████████████████████████████████████████"
echo "  RISC-V Alpine Linux — ISA Integration Boot"
echo "  Register + Syscall remapping active"
echo "████████████████████████████████████████████████████████"
echo ""

if [ -z "$QEMU_SYS" ]; then
    echo "ERROR: qemu-system-riscv64 not found."
    echo "Run bash build.sh first to build QEMU."
    exit 1
fi

if [ -z "$QEMU_BIOS" ]; then
    echo "ERROR: OpenSBI BIOS not found."
    echo "Run bash build.sh first."
    exit 1
fi

echo "[ISA] QEMU system: $QEMU_SYS"
echo "[ISA] Register keyring: $REGISTER_KEYRING"
echo "[ISA] Syscall keyring:  $SYSCALL_KEYRING"
echo ""
echo "Press Ctrl+A then X to exit QEMU"
echo ""

"$QEMU_SYS" \
    -machine virt \
    -nographic \
    -m 512M \
    -bios "$QEMU_BIOS" \
    -kernel "$ALPINE_DIR/kernel_extract/boot/vmlinux-6.19.11+deb14-riscv64" \
    -initrd "$ALPINE_DIR/initramfs.cpio.gz" \
    -drive file="$ALPINE_DIR/alpine-riscv64.img",format=raw,id=hd0,if=none \
    -device virtio-blk-device,drive=hd0 \
    -append "root=/dev/vda rw console=ttyS0" \
    -netdev user,id=net0 \
    -device virtio-net-device,netdev=net0
