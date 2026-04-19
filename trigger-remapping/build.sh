#!/bin/bash
# RISC-V Trigger Remapping — Portable Build Script
# Downloads QEMU 8.2.0, applies opcode patch, builds on any Ubuntu 22.04
set -e

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PHASE1="$(realpath "$BASE_DIR/../phase1" 2>/dev/null || echo "$BASE_DIR/../phase1")"
QEMU_SRC="$PHASE1/qemu-8.2.0"
QEMU_BIN="$QEMU_SRC/build/qemu-riscv64"

GREEN='\033[0;32m'; RED='\033[0;31m'; CYAN='\033[0;36m'; NC='\033[0m'

echo -e "${CYAN}"
echo "████████████████████████████████████████████████████████"
echo "  RISC-V Trigger Remapping — Portable Build"
echo "  Opcode patch + QEMU 8.2.0"
echo "████████████████████████████████████████████████████████"
echo -e "${NC}"

# Step 1: Dependencies
echo -e "${CYAN}[1/5] Installing dependencies...${NC}"
sudo apt-get update -qq
sudo apt-get install -y build-essential gcc make pkg-config \
    clang lld ninja-build git wget libglib2.0-dev \
    libpixman-1-dev libslirp-dev python3 2>/dev/null || true
echo -e "${GREEN}    Dependencies OK ✓${NC}"

# Step 2: /etc/isa/map
echo -e "\n${CYAN}[2/5] Setting up /etc/isa/map...${NC}"
sudo mkdir -p /etc/isa
sudo touch /etc/isa/map
sudo chown root:$(whoami) /etc/isa/map
sudo chmod 640 /etc/isa/map
echo -e "${GREEN}    /etc/isa/map (640) ✓${NC}"

# Step 3: Download QEMU
echo -e "\n${CYAN}[3/5] Setting up QEMU 8.2.0 source...${NC}"
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

# Step 4: Apply opcode patch
echo -e "\n${CYAN}[4/5] Applying opcode patch...${NC}"
cp "$BASE_DIR/isa_mapping.h" "$QEMU_SRC/target/riscv/isa_mapping.h"

python3 - "$QEMU_SRC/target/riscv/translate.c" << 'PYEOF'
import sys
path = sys.argv[1]
content = open(path).read()
if "isa_mapping.h" not in content:
    content = content.replace(
        '#include "instmap.h"',
        '#include "instmap.h"\n#include "isa_mapping.h"')
    print("    isa_mapping.h included ✓")
else:
    print("    isa_mapping.h already included ✓")
if "isa_decode_instruction" not in content:
    target = '        for (size_t i = 0; i < ARRAY_SIZE(decoders); ++i) {'
    hook = ('        #ifdef CONFIG_LINUX_USER\n'
            '        opcode32 = isa_decode_instruction(opcode32);\n'
            '        ctx->opcode = opcode32;\n'
            '        #endif\n'
            '        for (size_t i = 0; i < ARRAY_SIZE(decoders); ++i) {')
    if target in content:
        content = content.replace(target, hook, 1)
        print("    isa_decode_instruction hook added ✓")
else:
    print("    hook already present ✓")
open(path, 'w').write(content)
PYEOF

SRC_SUM=$(sha256sum "$BASE_DIR/isa_mapping.h" | cut -d' ' -f1)
DST_SUM=$(sha256sum "$QEMU_SRC/target/riscv/isa_mapping.h" | cut -d' ' -f1)
[ "$SRC_SUM" = "$DST_SUM" ] && \
    echo -e "${GREEN}    isa_mapping.h checksum verified ✓${NC}" || \
    { echo -e "${RED}    Checksum mismatch ✗${NC}"; exit 1; }

# Step 5: Build QEMU
echo -e "\n${CYAN}[5/5] Building QEMU 8.2.0 (opcode patch only)...${NC}"
cd "$QEMU_SRC"
mkdir -p build && cd build
if [ ! -f "build.ninja" ]; then
    ../configure --target-list=riscv64-linux-user \
        --disable-gtk --disable-sdl --disable-opengl \
        --enable-slirp 2>/dev/null
fi
make qemu-riscv64 -j$(nproc) 2>/dev/null
echo -e "${GREEN}    QEMU built ✓${NC}"
[ -f "$QEMU_BIN" ] && \
    echo -e "${GREEN}    Binary: $QEMU_BIN ✓${NC}" || \
    { echo -e "${RED}    Build failed ✗${NC}"; exit 1; }
ln -sf "$QEMU_BIN" "$BASE_DIR/qemu-riscv64"
echo -e "${GREEN}    Symlink created ✓${NC}"

echo -e "${CYAN}"
echo "████████████████████████████████████████████████████████"
echo "  Build Complete! Now run:"
echo "    bash trigger/trigger_demo.sh"
echo "    bash audit.sh"
echo "████████████████████████████████████████████████████████"
echo -e "${NC}"
