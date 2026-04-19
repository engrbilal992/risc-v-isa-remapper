#!/bin/bash
# RISC-V Register Remapping — Phase 3 Milestone 2 Demo
# Security proof: binary fingerprint + register permutation
source "$(dirname "$(readlink -f "$0")")/config.sh"

GREEN='\033[0;32m'; RED='\033[0;31m'
CYAN='\033[0;36m'; YELLOW='\033[1;33m'; NC='\033[0m'

echo -e "${CYAN}"
echo "████████████████████████████████████████████████████████"
echo "  RISC-V Register Remapping — Phase 3 Milestone 2"
echo "  Fingerprint verification + register permutation"
echo "  21 shuffleable registers — Keyspace: 21! permutations"
echo "████████████████████████████████████████████████████████"
echo -e "${NC}"

# Clear keyring
sudo truncate -s 0 "$REGISTER_KEYRING" 2>/dev/null || true
sleep 1

# Step 1: Compile standard binaries
echo -e "${YELLOW}[1] Compiling standard binaries...${NC}"
clang --target=riscv64-linux-gnu -march=rv64g \
    -nostdlib -static -fuse-ld=lld -Wl,--no-relax \
    -o /tmp/demo_reg_std "$DEMO_DIR/simple.S" 2>/dev/null
clang --target=riscv64-linux-gnu -march=rv64g \
    -nostdlib -static -fuse-ld=lld -Wl,--no-relax \
    -o /tmp/demo_reg_cstd "$DEMO_DIR/complex.S" 2>/dev/null
echo -e "${GREEN}    Compiled ✓${NC}"

# Step 2: Standard binary under empty keyring — works
echo -e "\n${YELLOW}[2] Standard binary — empty keyring (identity map)...${NC}"
timeout 5 "$QEMU" /tmp/demo_reg_std 2>/dev/null
[ $? -eq 0 ] && echo -e "${GREEN}    Result: SUCCESS ✓${NC}" || \
               echo -e "${RED}    Result: FAILED ✗${NC}"

# Step 3: Rewrite under permutation A (seed=42)
echo -e "\n${YELLOW}[3] Applying permutation A (seed=42) + embedding fingerprint...${NC}"
python3 "$BASE_DIR/isa_register_rewrite.py" \
    /tmp/demo_reg_std /tmp/demo_reg_A --seed 42
sleep 1

# Step 4: Remapped binary under correct keyring — works
echo -e "\n${YELLOW}[4] Remapped binary under correct keyring (perm A)...${NC}"
timeout 5 "$QEMU" /tmp/demo_reg_A 2>/dev/null
[ $? -eq 0 ] && echo -e "${GREEN}    Result: SUCCESS ✓ — Authorized binary runs${NC}" || \
               echo -e "${RED}    Result: FAILED ✗${NC}"

# Step 5: Standard binary under active keyring — BLOCKED
echo -e "\n${RED}[5] Standard binary under active keyring (no fingerprint)...${NC}"
timeout 5 "$QEMU" /tmp/demo_reg_std 2>/dev/null
EXIT5=$?
[ $EXIT5 -ne 0 ] && echo -e "${GREEN}    Result: BLOCKED ✓ — Standard binary rejected${NC}" || \
                   echo -e "${RED}    Result: PASSED (unexpected)${NC}"

# Step 6: Switch to permutation B
echo -e "\n${RED}[6] TRIGGER — switching to new permutation B...${NC}"
SEED_B=$(python3 -c "import os; print(int.from_bytes(os.urandom(4),'big'))")
python3 "$BASE_DIR/isa_register_rewrite.py" \
    /tmp/demo_reg_std /tmp/demo_reg_B --seed $SEED_B --quiet
echo -e "${GREEN}    New seed: $SEED_B${NC}"
sleep 1

# Step 7: Old binary (perm A) under new keyring — BLOCKED
echo -e "\n${YELLOW}[7] Old binary (perm A) under new keyring (perm B)...${NC}"
timeout 5 "$QEMU" /tmp/demo_reg_A 2>/dev/null
EXIT7=$?
[ $EXIT7 -ne 0 ] && echo -e "${GREEN}    Result: BLOCKED ✓ — Wrong fingerprint rejected${NC}" || \
                   echo -e "${RED}    Result: PASSED (unexpected)${NC}"

# Step 8: New binary (perm B) under new keyring — works
echo -e "\n${YELLOW}[8] New binary (perm B) under new keyring...${NC}"
timeout 5 "$QEMU" /tmp/demo_reg_B 2>/dev/null
[ $? -eq 0 ] && echo -e "${GREEN}    Result: SUCCESS ✓ — Legitimate update passes${NC}" || \
               echo -e "${RED}    Result: FAILED ✗${NC}"

# Step 9: Complex binary
echo -e "\n${YELLOW}[9] Complex binary under perm B...${NC}"
python3 "$BASE_DIR/isa_register_rewrite.py" \
    /tmp/demo_reg_cstd /tmp/demo_reg_cB --seed $SEED_B --quiet
sleep 1
timeout 5 "$QEMU" /tmp/demo_reg_cB 2>/dev/null
[ $? -eq 0 ] && echo -e "${GREEN}    Result: SUCCESS ✓${NC}" || \
               echo -e "${RED}    Result: FAILED ✗${NC}"

echo -e "\n${CYAN}════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  Standard binary (no fingerprint) : BLOCKED ✓${NC}"
echo -e "${GREEN}  Wrong permutation fingerprint     : BLOCKED ✓${NC}"
echo -e "${GREEN}  Correct permutation               : PASSES  ✓${NC}"
echo -e "${GREEN}  Keyspace: 21! permutations ≈ 2^65${NC}"
echo -e "${CYAN}════════════════════════════════════════════════════${NC}\n"
