#!/bin/bash
# Phase 3 Build Script
# Auto-copies syscall_mapping.h into QEMU tree, checksums, rebuilds
set -e
source "$(dirname "$(readlink -f "$0")")/config.sh"

GREEN='\033[0;32m'; RED='\033[0;31m'; CYAN='\033[0;36m'; NC='\033[0m'

echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}  Phase 3 — Build Script${NC}"
echo -e "${CYAN}========================================${NC}"

# Step 1: Create /etc/isa/syscall_keyring dir and permissions
echo -e "\n${CYAN}[1] Setting up /etc/isa/...${NC}"
sudo mkdir -p /etc/isa
sudo touch /etc/isa/syscall_keyring
sudo chown root:$(whoami) /etc/isa/syscall_keyring
sudo chmod 660 /etc/isa/syscall_keyring
echo -e "${GREEN}    /etc/isa/syscall_keyring ready ✓${NC}"

# Step 2: Copy syscall_mapping.h into QEMU tree
echo -e "\n${CYAN}[2] Copying syscall_mapping.h into QEMU tree...${NC}"
cp "$SYSCALL_MAPPING_H" "$QEMU_SYSCALL_H_DEST"

# Step 3: Checksum verification — fail build if mismatch
SRC_SUM=$(sha256sum "$SYSCALL_MAPPING_H" | cut -d' ' -f1)
DST_SUM=$(sha256sum "$QEMU_SYSCALL_H_DEST" | cut -d' ' -f1)
if [ "$SRC_SUM" != "$DST_SUM" ]; then
    echo -e "${RED}ERROR: syscall_mapping.h checksum mismatch — build aborted${NC}"
    exit 1
fi
echo -e "${GREEN}    Checksum verified ✓ ($SRC_SUM)${NC}"

# Step 4: Patch syscall.c if not already patched
echo -e "\n${CYAN}[3] Checking QEMU syscall.c patch...${NC}"
SYSCALL_C="$PHASE1/qemu-8.2.0/linux-user/syscall.c"
if ! grep -q "syscall_mapping.h" "$SYSCALL_C"; then
    # Add include after first #include line
    sed -i '1s|^|#include "syscall_mapping.h"\n|' "$SYSCALL_C"
    echo -e "${GREEN}    Added #include syscall_mapping.h ✓${NC}"
else
    echo -e "${GREEN}    Already patched ✓${NC}"
fi

# Check if translation line exists
if ! grep -q "syscall_translate" "$SYSCALL_C"; then
    # Insert translation before do_syscall1 call at line ~13658
    sed -i 's/ret = do_syscall1(cpu_env, num,/num = syscall_translate(num);\n    ret = do_syscall1(cpu_env, num,/' "$SYSCALL_C"
    echo -e "${GREEN}    Added syscall_translate hook ✓${NC}"
else
    echo -e "${GREEN}    Translation hook already present ✓${NC}"
fi

# Step 5: Rebuild QEMU
echo -e "\n${CYAN}[4] Rebuilding patched QEMU...${NC}"
cd "$PHASE1/qemu-8.2.0/build"
make qemu-riscv64 -j$(nproc) 2>/dev/null
echo -e "${GREEN}    QEMU rebuilt ✓${NC}"

echo -e "\n${CYAN}========================================${NC}"
echo -e "${GREEN}  Build complete!${NC}"
echo -e "${CYAN}========================================${NC}\n"
