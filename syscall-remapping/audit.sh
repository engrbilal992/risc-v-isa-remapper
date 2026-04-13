#!/bin/bash
# Phase 3 — Audit Script
source "$(dirname "$(readlink -f "$0")")/config.sh"

GREEN='\033[0;32m'; RED='\033[0;31m'; CYAN='\033[0;36m'; NC='\033[0m'
PASS=0; FAIL=0

check() {
    local name=$1; local result=$2
    if [ "$result" = "PASS" ]; then
        echo -e "  ${GREEN}✓ $name${NC}"; PASS=$((PASS+1))
    else
        echo -e "  ${RED}✗ $name: $result${NC}"; FAIL=$((FAIL+1))
    fi
}

echo -e "${CYAN}"
echo "════════════════════════════════════════════════════"
echo "  RISC-V Phase 3 — Syscall Remapping Audit"
echo "════════════════════════════════════════════════════"
echo -e "${NC}"

echo -e "${CYAN}--- STATIC CHECKS ---${NC}"

# S1: syscall_mapping.h exists in phase3
[ -f "$BASE_DIR/syscall_mapping.h" ] && check "S1: syscall_mapping.h exists" "PASS" || check "S1: syscall_mapping.h missing" "FAIL"

# S2: syscall_mapping.h copied into QEMU tree and matches
SRC_SUM=$(sha256sum "$SYSCALL_MAPPING_H" 2>/dev/null | cut -d' ' -f1)
DST_SUM=$(sha256sum "$QEMU_SYSCALL_H_DEST" 2>/dev/null | cut -d' ' -f1)
[ "$SRC_SUM" = "$DST_SUM" ] && check "S2: syscall_mapping.h checksum matches QEMU tree" "PASS" || check "S2: checksum mismatch" "FAIL"

# S3: QEMU syscall.c patched
grep -q "syscall_translate" "$QEMU_SYSCALL_C" 2>/dev/null && check "S3: QEMU syscall.c has translation hook" "PASS" || check "S3: QEMU not patched" "FAIL"

# S4: mtime race condition fix present
grep -q "after successful read" "$BASE_DIR/syscall_mapping.h" 2>/dev/null && check "S4: mtime race fix present" "PASS" || check "S4: mtime race not fixed" "FAIL"

# S5: keyring permissions
perms=$(stat -c "%a" "$ISA_SYSCALL_KEYRING" 2>/dev/null)
[ "$perms" = "660" ] || [ "$perms" = "600" ] && check "S5: syscall_keyring permissions ($perms)" "PASS" || check "S5: syscall_keyring permissions" "FAIL — $perms"

# S6: os.urandom used
grep -q "urandom" "$SYSCALL_REWRITER" && check "S6: os.urandom in rewriter" "PASS" || check "S6: weak seed" "FAIL"

# S7: No hardcoded paths — exclude comment lines and the check itself
result=$(grep -rn "Desktop\|/home/muhammadbilal" "$BASE_DIR"/*.py "$BASE_DIR"/*.sh 2>/dev/null \
    | grep -v "^.*:.*#" \
    | grep -v "audit.sh:[0-9]*:.*grep")
[ -z "$result" ] && check "S7: No hardcoded paths" "PASS" || check "S7: Hardcoded paths found" "FAIL — $result"

# S8: isa.env exists
[ -f "$BASE_DIR/isa.env" ] && check "S8: isa.env exists" "PASS" || check "S8: isa.env missing" "FAIL"

echo -e "\n${CYAN}--- LIVE TESTS ---${NC}"

# Clear keyring before tests
sudo truncate -s 0 "$ISA_SYSCALL_KEYRING"

# Compile binaries
clang --target=riscv64-linux-gnu -march=rv64g -nostdlib -static -fuse-ld=lld -O1 \
    -o /tmp/audit_simple "$DEMO_DIR/simple.c" 2>/dev/null
clang --target=riscv64-linux-gnu -march=rv64g -nostdlib -static -fuse-ld=lld -O1 \
    -o /tmp/audit_complex "$DEMO_DIR/complex.c" 2>/dev/null

# Rewrite with seed A=42
python3 "$SYSCALL_REWRITER" /tmp/audit_simple /tmp/audit_simple_A --seed 42 \
    --keyring "$ISA_SYSCALL_KEYRING" --quiet
python3 "$SYSCALL_REWRITER" /tmp/audit_complex /tmp/audit_complex_A --seed 42 \
    --keyring "$ISA_SYSCALL_KEYRING" --quiet
sleep 1

# L1: Simple binary runs under perm A
timeout 5 "$QEMU" /tmp/audit_simple_A 2>/dev/null
[ $? -eq 0 ] && check "L1: Simple binary runs under perm A" "PASS" || check "L1: Simple binary" "FAIL"

# L2: Complex binary runs under perm A
timeout 5 "$QEMU" /tmp/audit_complex_A 2>/dev/null
[ $? -eq 0 ] && check "L2: Complex binary runs under perm A" "PASS" || check "L2: Complex binary" "FAIL"

# Switch to perm B
NEW_SEED=$(python3 -c "import os; print(int.from_bytes(os.urandom(4),'big'))")
python3 "$SYSCALL_REWRITER" /tmp/audit_simple /tmp/audit_simple_B --seed $NEW_SEED \
    --keyring "$ISA_SYSCALL_KEYRING" --quiet
sleep 1

# L3: Old binary fails under perm B
timeout 5 "$QEMU" /tmp/audit_simple_A 2>/dev/null
[ $? -ne 0 ] && check "L3: Old binary blocked under perm B" "PASS" || check "L3: Old binary not blocked" "FAIL"

# L4: New binary runs under perm B — sleep already done above
timeout 5 "$QEMU" /tmp/audit_simple_B 2>/dev/null
[ $? -eq 0 ] && check "L4: New binary runs under perm B" "PASS" || check "L4: New binary" "FAIL"

echo ""
echo -e "${CYAN}════════════════════════════════════════════════════${NC}"
TOTAL=$((PASS+FAIL))
if [ $FAIL -eq 0 ]; then
    echo -e "${GREEN}  ALL $TOTAL CHECKS PASSED ✓${NC}"
else
    echo -e "${RED}  $FAIL/$TOTAL CHECKS FAILED ✗${NC}"
fi
echo -e "${CYAN}════════════════════════════════════════════════════${NC}"
echo ""
echo -e "  Git log:"
git -C "$BASE_DIR" log --oneline 2>/dev/null || echo "  (git not initialized yet)"
echo ""
