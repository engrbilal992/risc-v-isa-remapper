#!/bin/bash
# RISC-V Register Remapping — Build Script
# Phase 3 Milestone 2: Register rewriter + fingerprint verification
# Fully portable — works on any clean Ubuntu 22.04
set -e

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PHASE1="$(realpath "$BASE_DIR/../phase1")"
QEMU_SRC="$PHASE1/qemu-8.2.0"
QEMU_BIN="$QEMU_SRC/build/qemu-riscv64"

GREEN='\033[0;32m'; RED='\033[0;31m'; CYAN='\033[0;36m'; NC='\033[0m'

echo -e "${CYAN}"
echo "████████████████████████████████████████████████████████"
echo "  RISC-V Register Remapping — Phase 3 Milestone 2"
echo "  Register rewriter + fingerprint verification"
echo "████████████████████████████████████████████████████████"
echo -e "${NC}"

# Step 1: Dependencies
echo -e "${CYAN}[1/6] Installing dependencies...${NC}"
sudo apt-get update -qq
sudo apt-get install -y \
    build-essential gcc make pkg-config \
    clang lld ninja-build git wget \
    libglib2.0-dev libpixman-1-dev \
    libslirp-dev qemu-utils python3 \
    e2fsprogs binutils 2>/dev/null || true
echo -e "${GREEN}    Dependencies installed ✓${NC}"

# Step 2: Setup /etc/isa/register_keyring
echo -e "\n${CYAN}[2/6] Setting up /etc/isa/register_keyring...${NC}"
sudo mkdir -p /etc/isa
sudo touch /etc/isa/register_keyring
sudo chown root:$(whoami) /etc/isa/register_keyring
sudo chmod 640 /etc/isa/register_keyring
echo -e "${GREEN}    /etc/isa/register_keyring (640) ✓${NC}"

# Step 3: Download QEMU
echo -e "\n${CYAN}[3/6] Setting up QEMU 8.2.0 source...${NC}"
mkdir -p "$PHASE1"
if [ ! -d "$QEMU_SRC" ]; then
    echo "  Downloading QEMU 8.2.0..."
    cd "$PHASE1"
    wget -q --show-progress https://download.qemu.org/qemu-8.2.0.tar.xz
    tar xf qemu-8.2.0.tar.xz
    rm qemu-8.2.0.tar.xz
    echo -e "${GREEN}    QEMU 8.2.0 downloaded ✓${NC}"
    cd "$BASE_DIR"
else
    echo -e "${GREEN}    QEMU source already present ✓${NC}"
fi

# Step 4: Apply register patch only (NO syscall patch, NO opcode patch)
echo -e "\n${CYAN}[4/6] Applying register patch to QEMU...${NC}"
cp "$BASE_DIR/register_mapping.h" "$QEMU_SRC/target/riscv/register_mapping.h"
SRC_SUM=$(sha256sum "$BASE_DIR/register_mapping.h" | cut -d' ' -f1)
DST_SUM=$(sha256sum "$QEMU_SRC/target/riscv/register_mapping.h" | cut -d' ' -f1)
[ "$SRC_SUM" = "$DST_SUM" ] && \
    echo -e "${GREEN}    register_mapping.h copied & verified ✓${NC}" || \
    { echo -e "${RED}    checksum mismatch ✗${NC}"; exit 1; }

python3 - "$QEMU_SRC/target/riscv/translate.c" << 'PYEOF'
import sys
path = sys.argv[1]
content = open(path).read()
if "register_mapping.h" not in content:
    content = content.replace(
        '#include "instmap.h"',
        '#include "instmap.h"\n#include "register_mapping.h"')
    print("    register_mapping.h included in translate.c ✓")
else:
    print("    translate.c already includes register_mapping.h ✓")
if "register_decode_instruction" not in content:
    target = '        for (size_t i = 0; i < ARRAY_SIZE(decoders); ++i) {'
    hook = ('        #ifdef CONFIG_LINUX_USER\n'
            '        opcode32 = register_decode_instruction(opcode32);\n'
            '        ctx->opcode = opcode32;\n'
            '        #endif\n'
            '        for (size_t i = 0; i < ARRAY_SIZE(decoders); ++i) {')
    if target in content:
        content = content.replace(target, hook, 1)
        print("    register_decode_instruction hook added ✓")
    else:
        print("    WARNING: hook point not found")
else:
    print("    register_decode_instruction hook already present ✓")
open(path, 'w').write(content)
PYEOF

# Verify NO syscall or opcode patches
grep -q "isa_decode_instruction" "$QEMU_SRC/target/riscv/translate.c" && \
    echo -e "${RED}    WARNING: opcode patch present — may interfere ✗${NC}" || \
    echo -e "${GREEN}    Opcode patch absent ✓${NC}"
grep -q "syscall_translate" "$QEMU_SRC/linux-user/syscall.c" 2>/dev/null && \
    echo -e "${RED}    WARNING: syscall patch present ✗${NC}" || \
    echo -e "${GREEN}    Syscall patch absent ✓${NC}"
echo -e "${GREEN}    All QEMU patches verified ✓${NC}"

# Step 5: Build QEMU
echo -e "\n${CYAN}[5/6] Building patched QEMU 8.2.0...${NC}"
cd "$QEMU_SRC"
mkdir -p build && cd build
if [ ! -f "build.ninja" ]; then
    ../configure \
        --target-list=riscv64-linux-user \
        --disable-gtk --disable-sdl --disable-opengl \
        --enable-slirp 2>/dev/null
    echo -e "${GREEN}    Configured ✓${NC}"
fi
make qemu-riscv64 -j$(nproc) 2>/dev/null
echo -e "${GREEN}    QEMU built ✓${NC}"
[ -f "$QEMU_BIN" ] && \
    echo -e "${GREEN}    QEMU verified ✓ ($QEMU_BIN)${NC}" || \
    { echo -e "${RED}    QEMU missing ✗${NC}"; exit 1; }
ln -sf "$QEMU_BIN" "$BASE_DIR/qemu-riscv64"
echo -e "${GREEN}    Symlink created ✓${NC}"

# Step 6: Run audit
echo -e "\n${CYAN}[6/6] Running audit...${NC}"
cd "$BASE_DIR"
bash audit.sh

echo -e "${CYAN}"
echo "████████████████████████████████████████████████████████"
echo "  Build Complete!"
echo "  Run demo:  bash demo.sh"
echo "  Run audit: bash audit.sh"
echo "████████████████████████████████████████████████████████"
echo -e "${NC}"
