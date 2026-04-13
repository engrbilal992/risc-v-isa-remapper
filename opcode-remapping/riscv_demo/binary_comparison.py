#!/usr/bin/env python3
"""
Binary Comparison — Original vs Remapped RISC-V
Shows side-by-side 1s and 0s of instruction encoding.
Author: Muhammad Bilal
"""

import random
import struct

# Generate Boot A mapping (seed=42)
OPCODES = [0x33,0x13,0x03,0x23,0x63,0x6F,0x67,0x37,0x17,0x0F,0x3B,0x1B]
r = random.Random(42)
s = OPCODES[:]
r.shuffle(s)
mapping = dict(zip(OPCODES, s))
reverse = {v: k for k, v in mapping.items()}

# Read both binaries
with open('hello', 'rb') as f:
    orig = f.read()
with open('hello_bootA', 'rb') as f:
    remap = f.read()

# .text section starts at offset 0x144
offset = 0x144

print("=" * 80)
print("  RISC-V Binary Comparison: Original vs Remapped (seed=42)")
print("=" * 80)
print(f"  {'Original (standard RISC-V)':^35} {'Remapped (Boot A)':^35}")
print(f"  {'-'*35} {'-'*35}")

for i in range(20):
    o  = struct.unpack_from('<I', orig,  offset + i*4)[0]
    rm = struct.unpack_from('<I', remap, offset + i*4)[0]

    orig_op  = o  & 0x7F
    remap_op = rm & 0x7F

    diff = "<-- opcode changed" if o != rm else ""

    print(f"  {o:032b}  {rm:032b}  {diff}")

print("=" * 80)
print("\n  OPCODE MAPPING TABLE (seed=42):")
print(f"  {'Original Opcode':^20} {'Remapped To':^20} {'Type'}")
print(f"  {'-'*60}")

names = {
    0x33:"OP (ADD/SUB)", 0x13:"OP-IMM (ADDI)",
    0x03:"LOAD",         0x23:"STORE",
    0x63:"BRANCH",       0x6F:"JAL",
    0x67:"JALR",         0x37:"LUI",
    0x17:"AUIPC",        0x0F:"FENCE",
    0x3B:"OP-32",        0x1B:"OP-IMM-32",
}

for orig_op, mapped_op in mapping.items():
    changed = " *" if orig_op != mapped_op else ""
    print(f"  {orig_op:08b} (0x{orig_op:02X})       "
          f"{mapped_op:08b} (0x{mapped_op:02X})       "
          f"{names.get(orig_op,'')}{changed}")

print("\n  * = changed")
print("  SYSTEM opcode 0x73 is protected and never remapped.")
print("=" * 80)
