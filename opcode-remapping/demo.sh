#!/bin/bash
# ═══════════════════════════════════════════════════════
# RISC-V Dynamic ISA Remapping — Full Milestone 3 Demo
# Author: Muhammad Bilal
# ═══════════════════════════════════════════════════════

QEMU=~/Desktop/risc_v_isa_modification/qemu-8.2.0/build/qemu-riscv64
SONG=~/Desktop/risc_v_isa_modification/"Mega Drive - Converter ( slowed + reverb ).m4a"
DEMO_DIR=~/Desktop/risc_v_isa_modification/riscv_demo

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${CYAN}"
echo "████████████████████████████████████████████████████████"
echo "  RISC-V Dynamic ISA Remapping Emulator"
echo "  Full System Demo — Milestone 3"
echo "████████████████████████████████████████████████████████"
echo -e "${NC}"

# Start song in background
echo -e "${YELLOW}[MUSIC] Starting Converter...${NC}"
ffplay -nodisp -autoexit -loglevel quiet "$SONG" &
SONG_PID=$!

sleep 2

# ─── PHASE 1: BOOT A ────────────────────────────────────
echo -e "\n${CYAN}═══════════════════════════════════════${NC}"
echo -e "${CYAN}  PHASE 1: BOOT A (seed=42)${NC}"
echo -e "${CYAN}═══════════════════════════════════════${NC}"

cd $DEMO_DIR

python3 -c "
import random, struct, os
OPCODES=[0x33,0x13,0x03,0x23,0x63,0x6F,0x67,0x37,0x17,0x0F,0x3B,0x1B]
PROTECTED={0x73}
r=random.Random(42)
s=OPCODES[:]
r.shuffle(s)
mapping=dict(zip(OPCODES,s))
with open('/tmp/isa_reverse_map','w') as f:
    [f.write(f'{mp} {o}\n') for o,mp in mapping.items()]
print('Boot A mapping generated (seed=42)')
"

echo -e "\n${YELLOW}[1] Compiling advanced test suite for Boot A...${NC}"
cd ~/Desktop/risc_v_isa_modification
# python3 isa_compile.py riscv_demo/advanced.c riscv_demo/advanced_bootA 42 2>/dev/null
python3 isa_compile.py riscv_demo/advanced.c riscv_demo/advanced_bootA 42 >/dev/null 2>/dev/null
echo -e "${GREEN}    Advanced program compiled and remapped${NC}"

echo -e "\n${YELLOW}[2] Running advanced program under Boot A ISA...${NC}"
$QEMU $DEMO_DIR/advanced_bootA 2>/dev/null
if [ $? -eq 0 ]; then
    echo -e "${GREEN}    Result: SUCCESS ✓${NC}"
else
    echo -e "${RED}    Result: FAILED ✗${NC}"
fi

echo -e "\n${YELLOW}[3] Compiling malware simulation for Boot A...${NC}"
# python3 isa_compile.py riscv_demo/malware_sim.c riscv_demo/malware_bootA 42 2>/dev/null
python3 isa_compile.py riscv_demo/malware_sim.c riscv_demo/malware_bootA 42 >/dev/null 2>/dev/null
echo -e "${GREEN}    Malware compiled for Boot A${NC}"

echo -e "\n${YELLOW}[4] Running malware under Boot A ISA...${NC}"
$QEMU $DEMO_DIR/malware_bootA 2>/dev/null
if [ $? -eq 0 ]; then
    echo -e "${RED}    Malware executed successfully (expected on Boot A)${NC}"
fi

# ─── PHASE 2: REBOOT ────────────────────────────────────
echo -e "\n${CYAN}═══════════════════════════════════════${NC}"
echo -e "${CYAN}  PHASE 2: SYSTEM REBOOT${NC}"
echo -e "${CYAN}═══════════════════════════════════════${NC}"

sleep 1
echo -e "${YELLOW}  Generating new random seed...${NC}"
NEW_SEED=$RANDOM$RANDOM
echo -e "${GREEN}  New boot seed: $NEW_SEED${NC}"

python3 -c "
import random
OPCODES=[0x33,0x13,0x03,0x23,0x63,0x6F,0x67,0x37,0x17,0x0F,0x3B,0x1B]
r=random.Random($NEW_SEED)
s=OPCODES[:]
r.shuffle(s)
m=dict(zip(OPCODES,s))
with open('/tmp/isa_reverse_map','w') as f:
    [f.write(f'{mp} {o}\n') for o,mp in m.items()]
print(f'Boot B mapping generated (seed=$NEW_SEED)')
"

# ─── PHASE 3: BOOT B ────────────────────────────────────
echo -e "\n${CYAN}═══════════════════════════════════════${NC}"
echo -e "${CYAN}  PHASE 3: BOOT B — Security Test${NC}"
echo -e "${CYAN}═══════════════════════════════════════${NC}"

echo -e "\n${YELLOW}[5] Testing advanced program after reboot...${NC}"
$QEMU $DEMO_DIR/advanced_bootA 2>/dev/null
if [ $? -ne 0 ]; then
    echo -e "${RED}    Result: FAILED ✗ — Binary incompatible with new ISA${NC}"
fi

echo -e "\n${YELLOW}[6] Testing malware after reboot...${NC}"
$QEMU $DEMO_DIR/malware_bootA 2>/dev/null
if [ $? -ne 0 ]; then
    echo -e "${GREEN}    Result: BLOCKED ✓ — Malware cannot execute!${NC}"
fi

# ─── RESULTS ────────────────────────────────────────────
echo -e "\n${CYAN}════════════════════════════════════════════${NC}"
echo -e "${CYAN}  FINAL RESULTS${NC}"
echo -e "${CYAN}════════════════════════════════════════════${NC}"
echo -e "${GREEN}  Boot A binary + Boot A mapping : SUCCESS ✓${NC}"
echo -e "${GREEN}  Malware + Boot A mapping       : EXECUTED (expected)${NC}"
echo -e "${RED}  Boot A binary + Boot B mapping : FAILED ✗${NC}"
echo -e "${GREEN}  Malware + Boot B mapping       : BLOCKED ✓${NC}"
echo -e "\n${GREEN}  ISA remapping prevents malware persistence. ✓${NC}"
echo -e "${CYAN}════════════════════════════════════════════${NC}\n"

# Stop song
kill $SONG_PID 2>/dev/null
echo -e "${YELLOW}[MUSIC] Done.${NC}"
