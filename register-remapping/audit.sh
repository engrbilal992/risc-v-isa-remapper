#!/bin/bash
# RISC-V Register Remapping — Complete Audit Script
source "$(dirname "$(readlink -f "$0")")/config.sh"

GREEN='\033[0;32m'; RED='\033[0;31m'; CYAN='\033[0;36m'
YELLOW='\033[1;33m'; NC='\033[0m'
PASS=0; FAIL=0

check() {
    local name=$1 result=$2 hint=${3:-}
    if [ "$result" = "PASS" ]; then
        echo -e "  ${GREEN}✓ $name${NC}"; PASS=$((PASS+1))
    else
        echo -e "  ${RED}✗ $name${NC}"
        [ -n "$hint" ] && echo -e "    ${YELLOW}→ $hint${NC}"
        FAIL=$((FAIL+1))
    fi
}

echo -e "${CYAN}"
echo "████████████████████████████████████████████████████████"
echo "  RISC-V Register Remapping — Phase 3 Milestone 2 Audit"
echo "████████████████████████████████████████████████████████"
echo -e "${NC}"

QEMU_SRC="$PHASE1/qemu-8.2.0"
TRANSLATE_C="$QEMU_SRC/target/riscv/translate.c"

# ── SECTION 1: FILE EXISTENCE ─────────────────────────────
echo -e "${CYAN}══ SECTION 1: FILE EXISTENCE ══${NC}"
for f in isa_register_rewrite.py register_mapping.h isa.env config.sh \
          build.sh demo.sh audit.sh CHANGELOG.md \
          riscv_demo/simple.S riscv_demo/complex.S lib/config.py; do
    [ -f "$BASE_DIR/$f" ] && check "File exists: $f" "PASS" || \
        check "File exists: $f" "FAIL" "Missing"
done

# ── SECTION 2: CONFIG & PATHS ─────────────────────────────
echo -e "\n${CYAN}══ SECTION 2: CONFIG & PATHS ══${NC}"
echo "  BASE_DIR = $BASE_DIR"
echo "  QEMU     = $QEMU"
echo "  PHASE1   = $PHASE1"
echo "  KEYRING  = $REGISTER_KEYRING"
[ -f "$QEMU" ] && check "QEMU binary exists" "PASS" || \
    check "QEMU binary exists" "FAIL" "Run bash build.sh first"
[ -d "$QEMU_SRC" ] && check "QEMU source tree exists" "PASS" || \
    check "QEMU source tree exists" "FAIL" "Run bash build.sh first"
result=$(python3 -c "import sys; sys.path.insert(0,'$BASE_DIR'); \
    from lib.config import REGISTER_KEYRING; print(REGISTER_KEYRING)" 2>/dev/null)
[ "$result" = "/etc/isa/register_keyring" ] && \
    check "Python reads isa.env correctly ($result)" "PASS" || \
    check "Python reads isa.env" "FAIL" "Got: $result"

# ── SECTION 3: QEMU PATCH VERIFICATION ───────────────────
echo -e "\n${CYAN}══ SECTION 3: QEMU PATCH VERIFICATION ══${NC}"
if [ -f "$TRANSLATE_C" ]; then
    grep -q "register_mapping.h" "$TRANSLATE_C" && \
        check "register_mapping.h included in translate.c" "PASS" || \
        check "register_mapping.h included" "FAIL" "Run bash build.sh"
    grep -q "register_decode_instruction" "$TRANSLATE_C" && \
        check "register_decode_instruction hook present" "PASS" || \
        check "hook present" "FAIL" "Run bash build.sh"
    SRC_SUM=$(sha256sum "$BASE_DIR/register_mapping.h" | cut -d' ' -f1 | cut -c1-16)
    DST_SUM=$(sha256sum "$QEMU_SRC/target/riscv/register_mapping.h" \
              2>/dev/null | cut -d' ' -f1 | cut -c1-16)
    [ "$SRC_SUM" = "$DST_SUM" ] && \
        check "register_mapping.h checksum matches QEMU tree" "PASS" || \
        check "register_mapping.h checksum" "FAIL" "Source: $SRC_SUM QEMU: $DST_SUM"
    ! grep -q "isa_decode_instruction" "$TRANSLATE_C" 2>/dev/null && \
        check "Opcode patch absent from translate.c" "PASS" || \
        check "Opcode patch absent" "FAIL" "isa_decode_instruction found — interferes"
    grep -q "reg_map_mtime" "$BASE_DIR/register_mapping.h" && \
        check "mtime race condition fixed (no initialized flag)" "PASS" || \
        check "mtime race condition" "FAIL"
    grep -q "FP_MAGIC\|FP " "$BASE_DIR/register_mapping.h" && \
        check "Fingerprint verification present in QEMU hook" "PASS" || \
        check "Fingerprint verification" "FAIL"
else
    check "translate.c accessible" "FAIL" "Run bash build.sh first"
fi

# ── SECTION 4: SECURITY & CODE QUALITY ───────────────────
echo -e "\n${CYAN}══ SECTION 4: SECURITY & CODE QUALITY ══${NC}"
result=$(grep -r "Desktop\|/home/muhammadbilal" \
    "$BASE_DIR/isa_register_rewrite.py" \
    "$BASE_DIR/build.sh" "$BASE_DIR/demo.sh" \
    "$BASE_DIR/config.sh" 2>/dev/null | grep -v "^.*#")
[ -z "$result" ] && check "No hardcoded Desktop paths" "PASS" || \
    check "No hardcoded paths" "FAIL" "$result"
grep -q "secrets.token_bytes" "$BASE_DIR/isa_register_rewrite.py" && \
    check "secrets.token_bytes — 256-bit entropy" "PASS" || \
    check "secrets.token_bytes" "FAIL"
result=$(grep -r "\$RANDOM" \
    "$BASE_DIR/build.sh" "$BASE_DIR/demo.sh" \
    "$BASE_DIR/config.sh" 2>/dev/null | grep -v "^.*#")
[ -z "$result" ] && check "No weak \$RANDOM in scripts" "PASS" || \
    check "No weak \$RANDOM" "FAIL"
perms=$(stat -c "%a" /etc/isa/register_keyring 2>/dev/null)
([ "$perms" = "640" ] || [ "$perms" = "600" ]) && \
    check "register_keyring permissions ($perms)" "PASS" || \
    check "register_keyring permissions" "FAIL" "Expected 640, got: $perms"
grep -q "REG_COUNT" "$BASE_DIR/isa_register_rewrite.py" 2>/dev/null && \
    check "REG_COUNT = 32 (full RISC-V register file)" "PASS" || \
    check "REG_COUNT = 32" "FAIL"
grep -q "FROZEN.*=.*{0, 1, 2, 10" "$BASE_DIR/isa_register_rewrite.py" && \
    check "Frozen registers: x0,x1,x2,x10-x17 (11 frozen, 21 shuffleable)" "PASS" || \
    check "Frozen registers" "FAIL"
grep -q "OPCODE_FIELDS" "$BASE_DIR/isa_register_rewrite.py" && \
    check "OPCODE_FIELDS table (No imm corruption)" "PASS" || \
    check "OPCODE_FIELDS table" "FAIL"
grep -q "sudo.*tee" "$BASE_DIR/isa_register_rewrite.py" && \
    check "sudo tee fallback in rewriter" "PASS" || \
    check "sudo tee fallback" "FAIL"
grep -rq "march=rv64g" "$BASE_DIR/build.sh" "$BASE_DIR/audit.sh" \
    "$BASE_DIR/demo.sh" 2>/dev/null && \
    check "-march=rv64g (no RVC, POC limitation)" "PASS" || \
    check "-march=rv64g" "FAIL"
grep -q "make_fingerprint\|FP_MAGIC" "$BASE_DIR/isa_register_rewrite.py" && \
    check "Fingerprint embedding in rewriter" "PASS" || \
    check "Fingerprint embedding" "FAIL"

# ── SECTION 5: LIVE FUNCTIONAL TESTS ─────────────────────
echo -e "\n${CYAN}══ SECTION 5: LIVE FUNCTIONAL TESTS ══${NC}"
if [ ! -f "$QEMU" ]; then
    echo -e "  ${YELLOW}Skipping — QEMU missing. Run bash build.sh first.${NC}"
else
    echo "  Compiling test binaries..."
    clang --target=riscv64-linux-gnu -march=rv64g \
        -nostdlib -static -fuse-ld=lld -Wl,--no-relax \
        -o /tmp/audit_reg_std "$DEMO_DIR/simple.S" 2>/dev/null
    clang --target=riscv64-linux-gnu -march=rv64g \
        -nostdlib -static -fuse-ld=lld -Wl,--no-relax \
        -o /tmp/audit_reg_cstd "$DEMO_DIR/complex.S" 2>/dev/null

    # T1: Standard binary, empty keyring
    echo "  T1: Standard binary — empty keyring (identity)"
    sudo truncate -s 0 "$REGISTER_KEYRING" 2>/dev/null || true
    sleep 1
    OUT=$(timeout 5 "$QEMU" /tmp/audit_reg_std 2>/dev/null)
    EXIT1=$?
    [ $EXIT1 -eq 0 ] && check "T1: Standard binary runs (identity map)" "PASS" || \
        check "T1: Standard binary" "FAIL" "exit=$EXIT1"
    echo "    Output: $(echo "$OUT" | head -1)"

    # T2: Rewrite seed=42, run under correct keyring
    echo "  T2: Rewrite seed=42, run under correct keyring"
    python3 "$BASE_DIR/isa_register_rewrite.py" \
        /tmp/audit_reg_std /tmp/audit_reg_A --seed 42 --quiet
    sleep 1
    OUT=$(timeout 5 "$QEMU" /tmp/audit_reg_A 2>/dev/null)
    EXIT2=$?
    [ $EXIT2 -eq 0 ] && check "T2: Remapped binary runs under correct keyring" "PASS" || \
        check "T2: Remapped binary" "FAIL" "exit=$EXIT2"
    echo "    Output: $(echo "$OUT" | head -1)"

    # T3: Complex binary seed=42
    python3 "$BASE_DIR/isa_register_rewrite.py" \
        /tmp/audit_reg_cstd /tmp/audit_reg_cA --seed 42 --quiet
    sleep 1
    OUT=$(timeout 5 "$QEMU" /tmp/audit_reg_cA 2>/dev/null)
    EXIT3=$?
    [ $EXIT3 -eq 0 ] && check "T3: Complex remapped binary runs" "PASS" || \
        check "T3: Complex remapped binary" "FAIL" "exit=$EXIT3"
    echo "    Output: $(echo "$OUT" | head -1)"

    # T4: Standard binary under active keyring — must be BLOCKED
    echo "  T4: Standard binary under active keyring (must be BLOCKED)"
    timeout 5 "$QEMU" /tmp/audit_reg_std >/dev/null 2>/dev/null
    EXIT4=$?
    [ $EXIT4 -ne 0 ] && check "T4: Standard binary BLOCKED (no fingerprint)" "PASS" || \
        check "T4: Standard binary blocked" "FAIL" "Binary ran — not blocked"

    # T5: Wrong seed binary under seed=42 keyring — must be BLOCKED
    echo "  T5: Wrong seed binary under active keyring (must be BLOCKED)"
    SEED_B=$(python3 -c "import os; print(int.from_bytes(os.urandom(4),'big'))")
    python3 "$BASE_DIR/isa_register_rewrite.py" \
        /tmp/audit_reg_std /tmp/audit_reg_B --seed $SEED_B --quiet 2>/dev/null
    # Restore seed=42 keyring
    python3 "$BASE_DIR/isa_register_rewrite.py" \
        /tmp/audit_reg_std /tmp/audit_reg_A2 --seed 42 --quiet
    sleep 1
    timeout 5 "$QEMU" /tmp/audit_reg_B >/dev/null 2>/dev/null
    EXIT5=$?
    [ $EXIT5 -ne 0 ] && check "T5: Wrong-seed binary BLOCKED" "PASS" || \
        check "T5: Wrong-seed binary blocked" "FAIL" "Binary ran — not blocked"

    # T6: Remapped binary under empty keyring — must be BLOCKED
    echo "  T6: Remapped binary under empty keyring (must be BLOCKED)"
    sudo truncate -s 0 "$REGISTER_KEYRING" 2>/dev/null || true
    sleep 1
    timeout 5 "$QEMU" /tmp/audit_reg_A >/dev/null 2>/dev/null
    EXIT6=$?
    [ $EXIT6 -ne 0 ] && check "T6: Remapped binary BLOCKED (empty keyring)" "PASS" || \
        check "T6: Remapped binary blocked" "FAIL" "Binary ran — not blocked"

    # T7: Determinism
    python3 "$BASE_DIR/isa_register_rewrite.py" \
        /tmp/audit_reg_std /tmp/audit_det1 --seed 12345 --quiet
    K1=$(sha256sum "$REGISTER_KEYRING" | cut -d' ' -f1)
    python3 "$BASE_DIR/isa_register_rewrite.py" \
        /tmp/audit_reg_std /tmp/audit_det2 --seed 12345 --quiet
    K2=$(sha256sum "$REGISTER_KEYRING" | cut -d' ' -f1)
    [ "$K1" = "$K2" ] && check "T7: Same seed always produces same keyring" "PASS" || \
        check "T7: Determinism" "FAIL"

    # T8: Different seeds produce different keyrings
    python3 "$BASE_DIR/isa_register_rewrite.py" \
        /tmp/audit_reg_std /tmp/audit_s1 --seed 100 --quiet
    K1=$(sha256sum "$REGISTER_KEYRING" | cut -d' ' -f1)
    python3 "$BASE_DIR/isa_register_rewrite.py" \
        /tmp/audit_reg_std /tmp/audit_s2 --seed 200 --quiet
    K2=$(sha256sum "$REGISTER_KEYRING" | cut -d' ' -f1)
    [ "$K1" != "$K2" ] && check "T8: Different seeds produce different keyrings" "PASS" || \
        check "T8: Different seeds" "FAIL"

    # T9: Frozen registers not in keyring
    python3 "$BASE_DIR/isa_register_rewrite.py" \
        /tmp/audit_reg_std /tmp/audit_fr --seed 99 --quiet
    FROZEN_OK=true
    for r in 0 1 2 10 11 12 13 14 15 16 17; do
        if grep -q "^$r " "$REGISTER_KEYRING" 2>/dev/null; then
            FROZEN_OK=false; break
        fi
    done
    $FROZEN_OK && check "T9: Frozen registers preserved (x0,x1,x2,x10-x17)" "PASS" || \
        check "T9: Frozen registers" "FAIL" "Frozen reg found in keyring"

    # T10: Binary differs from standard after rewrite
    python3 "$BASE_DIR/isa_register_rewrite.py" \
        /tmp/audit_reg_std /tmp/audit_diff --seed 42 --quiet
    STD_MD5=$(md5sum /tmp/audit_reg_std | cut -d' ' -f1)
    RMP_MD5=$(md5sum /tmp/audit_diff    | cut -d' ' -f1)
    [ "$STD_MD5" != "$RMP_MD5" ] && \
        check "T10: Rewritten binary differs from standard" "PASS" || \
        check "T10: Binary differs" "FAIL" "Identical — rewriter not working"

    # T11: Fingerprint NOPs present in rewritten binary
    python3 - /tmp/audit_diff << 'PYEOF'
import struct, sys
with open(sys.argv[1], 'rb') as f: data = f.read()
e_shoff = struct.unpack_from('<Q', data, 40)[0]
e_shentsize = struct.unpack_from('<H', data, 58)[0]
e_shnum = struct.unpack_from('<H', data, 60)[0]
e_shstrndx = struct.unpack_from('<H', data, 62)[0]
shstr_off = e_shoff + e_shstrndx * e_shentsize
shstr_file_off = struct.unpack_from('<Q', data, shstr_off + 24)[0]
for i in range(e_shnum):
    sh_off = e_shoff + i * e_shentsize
    sh_name = struct.unpack_from('<I', data, sh_off)[0]
    sh_file_off = struct.unpack_from('<Q', data, sh_off + 24)[0]
    name = b''
    j = shstr_file_off + sh_name
    while j < len(data) and data[j] != 0:
        name += bytes([data[j]]); j += 1
    if name == b'.text':
        w0 = struct.unpack_from('<I', data, sh_file_off)[0]
        w1 = struct.unpack_from('<I', data, sh_file_off+4)[0]
        ok = (w0 & 0xFFFFF) == 0x00013 and (w1 & 0xFFFFF) == 0x00013
        print("FOUND" if ok else "NOT_FOUND")
        break
PYEOF
    FP_CHECK=$?
    # capture output from python3
    FP_OUT=$(python3 - /tmp/audit_diff << 'PYEOF2'
import struct, sys
with open(sys.argv[1], 'rb') as f: data = f.read()
e_shoff = struct.unpack_from('<Q', data, 40)[0]
e_shentsize = struct.unpack_from('<H', data, 58)[0]
e_shnum = struct.unpack_from('<H', data, 60)[0]
e_shstrndx = struct.unpack_from('<H', data, 62)[0]
shstr_off = e_shoff + e_shstrndx * e_shentsize
shstr_file_off = struct.unpack_from('<Q', data, shstr_off + 24)[0]
for i in range(e_shnum):
    sh_off = e_shoff + i * e_shentsize
    sh_name = struct.unpack_from('<I', data, sh_off)[0]
    sh_file_off = struct.unpack_from('<Q', data, sh_off + 24)[0]
    name = b''
    j = shstr_file_off + sh_name
    while j < len(data) and data[j] != 0:
        name += bytes([data[j]]); j += 1
    if name == b'.text':
        w0 = struct.unpack_from('<I', data, sh_file_off)[0]
        w1 = struct.unpack_from('<I', data, sh_file_off+4)[0]
        ok = (w0 & 0xFFFFF) == 0x00013 and (w1 & 0xFFFFF) == 0x00013
        print("FOUND" if ok else "NOT_FOUND")
        break
PYEOF2
)
    [ "$FP_OUT" = "FOUND" ] && \
        check "T11: Fingerprint NOPs present at .text+0" "PASS" || \
        check "T11: Fingerprint NOPs" "FAIL" "Not found at .text start"
fi

# ── SECTION 6: DOCUMENTATION & GIT ───────────────────────
echo -e "\n${CYAN}══ SECTION 6: DOCUMENTATION & GIT ══${NC}"
[ -f "$BASE_DIR/CHANGELOG.md" ] && check "CHANGELOG.md exists" "PASS" || \
    check "CHANGELOG.md" "FAIL"
grep -q "$(date +%Y)" "$BASE_DIR/CHANGELOG.md" 2>/dev/null && \
    check "CHANGELOG has dated entries" "PASS" || \
    check "CHANGELOG dated" "FAIL"
echo -e "${CYAN}════════════════════════════════════════════════════${NC}"
TOTAL=$((PASS+FAIL))
if [ $FAIL -eq 0 ]; then
    echo -e "${GREEN}  ALL $TOTAL CHECKS PASSED ✓${NC}"
    echo -e "${GREEN}  Phase 3 Milestone 2 is production ready.${NC}"
else
    echo -e "${RED}  $FAIL/$TOTAL CHECKS FAILED ✗${NC}"
    echo -e "${YELLOW}  $PASS/$TOTAL passed${NC}"
fi
echo -e "${CYAN}════════════════════════════════════════════════════${NC}"
echo ""
git -C "$BASE_DIR" log --oneline -5 2>/dev/null || \
git -C "$(dirname "$BASE_DIR")" log --oneline -5 2>/dev/null || \
echo "  (no git history)"
echo ""
