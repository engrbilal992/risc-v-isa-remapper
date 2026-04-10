#!/bin/bash
# ISA Remapping - Central Config
# Source from bash: source "$(dirname "$0")/../config.sh"
# Python reads ISA_MAP via: os.environ.get("ISA_MAP", "/etc/isa/map")

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

QEMU="$BASE_DIR/../phase1/qemu-8.2.0/build/qemu-riscv64"
QEMU_SYSTEM="$BASE_DIR/../phase1/qemu-8.2.0/build/qemu-system-riscv64"
QEMU_BIOS="$BASE_DIR/../phase1/qemu-8.2.0/pc-bios/opensbi-riscv64-generic-fw_dynamic.bin"

export ISA_MAP="/etc/isa/map"

ISA_COMPILE="$BASE_DIR/isa_compile.py"
TRIGGER_SCRIPT="$BASE_DIR/trigger/isa_trigger.py"
ALPINE_IMG="$BASE_DIR/alpine/alpine-riscv64.img"
ALPINE_KERNEL="$BASE_DIR/alpine/kernel_extract/boot/vmlinux-6.19.11+deb14-riscv64"
ALPINE_INITRD="$BASE_DIR/alpine/initramfs.cpio.gz"
DEMO_DIR="$BASE_DIR/riscv_demo"
