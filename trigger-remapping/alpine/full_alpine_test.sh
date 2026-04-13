#!/bin/bash
source "$(dirname "$(readlink -f "$0")")/../config.sh"
source "$(dirname "$(readlink -f "$0")")/../lib/generate_mapping.sh"

echo "=== Full Alpine ISA Remapping Test ==="
echo ""

# Compile test binaries — isa_compile.py writes the map for seed=42
echo "[COMPILE] Building standard binaries..."
python3 "$ISA_COMPILE" "$DEMO_DIR/advanced.c" /tmp/alpine_std 42 >/dev/null 2>&1
python3 "$ISA_COMPILE" "$DEMO_DIR/malware_sim.c" /tmp/alpine_mal 42 >/dev/null 2>&1
echo '[MAPPING] ISA active seed=42'
# Sleep 1s so mtime is stable before QEMU reads the map
sleep 1

echo "[TEST 1] Standard binary under seed=42..."
timeout 5 "$QEMU" /tmp/alpine_std 2>/dev/null
EXIT_TEST1=$?
[ $EXIT_TEST1 -eq 0 ] && echo "  RESULT: SUCCESS ✓" || echo "  RESULT: FAILED ✗"

echo ""
echo "[TRIGGER] Firing ISA remap..."
NEW_SEED=$(python3 -c "import os; print(int.from_bytes(os.urandom(4),'big'))")
generate_mapping $NEW_SEED
echo "  New seed: $NEW_SEED"
sleep 1

echo ""
echo "[TEST 2] Old binary after remap (should fail)..."
timeout 5 "$QEMU" /tmp/alpine_std 2>/dev/null
[ $? -ne 0 ] && echo "  RESULT: BLOCKED ✓" || echo "  RESULT: PASSED (unexpected)"

echo ""
echo "[TEST 3] Malware after remap (should be blocked)..."
timeout 5 "$QEMU" /tmp/alpine_mal 2>/dev/null
[ $? -ne 0 ] && echo "  RESULT: BLOCKED ✓" || echo "  RESULT: EXECUTED (bad)"

echo ""
echo "[TEST 4] Legitimate update (recompile under new seed)..."
python3 "$ISA_COMPILE" "$DEMO_DIR/advanced.c" /tmp/alpine_updated $NEW_SEED >/dev/null 2>&1
sleep 1
timeout 5 "$QEMU" /tmp/alpine_updated 2>/dev/null
EXIT_TEST4=$?
[ $EXIT_TEST4 -eq 0 ] && echo "  RESULT: UPDATE PASSES ✓" || echo "  RESULT: FAILED ✗"

echo ""
echo "=== All Alpine ISA Tests Complete ==="

echo ""
echo "=== NOTE: Boot Alpine manually to verify inside-Alpine tests ==="
echo "Run: bash alpine/boot_alpine.sh"
echo "Inside Alpine run:"
echo "  /root/advanced > /dev/null && echo 'Standard: PASS'"
echo "  /root/advanced_remapped 2>/dev/null; [ \$? -eq 132 ] && echo 'Remapped: BLOCKED'"
echo "  /root/malware > /dev/null && echo 'Malware: runs'"
echo "  /root/malware_remapped 2>/dev/null; [ \$? -eq 132 ] && echo 'Malware remapped: BLOCKED'"
