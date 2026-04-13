#!/bin/bash
# RISC-V ISA Boot Automation Script
# Generates new random seed and mapping on every run
# Usage: ./boot.sh <binary>

QEMU=~/Desktop/risc_v_isa_modification/qemu-8.2.0/build/qemu-riscv64
REVERSE_MAP=/tmp/isa_reverse_map
BINARY=$1

if [ -z "$BINARY" ]; then
    echo "Usage: ./boot.sh <binary>"
    exit 1
fi

# Generate random seed
SEED=$RANDOM$RANDOM
echo "Boot seed: $SEED"

# Generate mapping and remap binary
python3 - <<EOF
import random, struct, shutil, os

OPCODES = [0x33,0x13,0x03,0x23,0x63,0x6F,0x67,0x37,0x17,0x0F,0x3B,0x1B]
PROTECTED = {0x73}
seed = $SEED
r = random.Random(seed)
s = OPCODES[:]
r.shuffle(s)
mapping = dict(zip(OPCODES, s))

# Write reverse map for QEMU
with open('$REVERSE_MAP', 'w') as f:
    for o, mp in mapping.items():
        f.write(f'{mp} {o}\n')

# Remap binary
shutil.copy('$BINARY', '$BINARY' + '_booted')
with open('$BINARY' + '_booted', 'rb') as f:
    data = bytearray(f.read())

i = 0; count = 0
while i < len(data)-3:
    w = struct.unpack_from('<I', data, i)[0]
    if (w&0x3) != 0x3:
        i += 2; continue
    op = w & 0x7F
    if op not in PROTECTED and op in mapping and mapping[op] != op:
        data[i:i+4] = struct.pack('<I', (w&~0x7F)|mapping[op])
        count += 1
    i += 4

with open('$BINARY' + '_booted', 'wb') as f:
    f.write(data)
os.chmod('$BINARY' + '_booted', 0o755)
print(f'Remapped {count} instructions -> $BINARY' + '_booted')
EOF

# Launch with patched QEMU
echo "Launching $BINARY under remapped ISA..."
$QEMU ${BINARY}_booted 2>/dev/null
echo "Exit code: $?"
