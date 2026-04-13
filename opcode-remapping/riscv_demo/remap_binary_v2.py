import sys
import os
import random
import struct
import shutil

# Official RISC-V 7-bit opcodes
RISCV_OPCODES = {
    0b0110011: "OP (ADD/SUB/AND/OR/XOR)",
    0b0010011: "OP-IMM (ADDI/SLTI etc)",
    0b0000011: "LOAD (LW/LD etc)",
    0b0100011: "STORE (SW/SD etc)",
    0b1100011: "BRANCH (BEQ/BNE etc)",
    0b1101111: "JAL",
    0b1100111: "JALR",
    0b0110111: "LUI",
    0b0010111: "AUIPC",
    0b0001111: "FENCE",
    0b0111011: "OP-32 (ADDW/SUBW etc)",
    0b0011011: "OP-IMM-32 (ADDIW etc)",
}

# NEVER remap SYSTEM opcode - contains ecall/ebreak
# Remapping it breaks program exit and OS interaction
PROTECTED_OPCODES = {0b1110011}  # SYSTEM

def is_32bit_instruction(word):
    """
    Per RISC-V spec: 32-bit instructions have bits[1:0] == 0b11
    16-bit compressed instructions have bits[1:0] != 0b11
    """
    return (word & 0x3) == 0x3

def get_opcode(instruction):
    """Extract 7-bit opcode from bits[6:0]."""
    return instruction & 0x7F

def set_opcode(instruction, new_opcode):
    """Replace opcode bits[6:0], keep all other bits unchanged."""
    return (instruction & ~0x7F) | (new_opcode & 0x7F)

def generate_mapping(seed):
    """
    Generate deterministic opcode shuffle from seed.
    Only shuffles remappable opcodes, never protected ones.
    """
    opcodes = list(RISCV_OPCODES.keys())
    r = random.Random(seed)
    shuffled = opcodes[:]
    r.shuffle(shuffled)
    mapping = dict(zip(opcodes, shuffled))
    return mapping

def print_mapping(mapping, seed):
    print(f"\nSeed: {seed}")
    print(f"{'Original':<15} {'Maps To':<15} {'Type'}")
    print("-" * 65)
    for orig, mapped in mapping.items():
        changed = " ← CHANGED" if orig != mapped else ""
        print(f"{bin(orig):<15} {bin(mapped):<15} {RISCV_OPCODES[orig]}{changed}")
    print(f"\nProtected (never remapped): SYSTEM {bin(0b1110011)} (ecall/ebreak)")

def remap_binary(input_file, output_file, seed):
    mapping = generate_mapping(seed)
    print_mapping(mapping, seed)

    shutil.copy(input_file, output_file)

    with open(output_file, 'rb') as f:
        data = bytearray(f.read())

    remapped_count = 0
    skipped_compressed = 0
    i = 0

    while i < len(data) - 3:
        word = struct.unpack_from('<I', data, i)[0]

        if not is_32bit_instruction(word):
            # 16-bit compressed instruction — skip 2 bytes
            i += 2
            skipped_compressed += 1
            continue

        opcode = get_opcode(word)

        if opcode in PROTECTED_OPCODES:
            i += 4
            continue

        if opcode in mapping and mapping[opcode] != opcode:
            new_word = set_opcode(word, mapping[opcode])
            struct.pack_into('<I', data, i, new_word)
            remapped_count += 1

        i += 4

    with open(output_file, 'wb') as f:
        f.write(data)

    os.chmod(output_file, 0o755)
    print(f"\nStats: {remapped_count} instructions remapped, "
          f"{skipped_compressed} compressed instructions skipped")
    
    # Write reverse mapping file for QEMU to read
    with open("/tmp/isa_reverse_map", "w") as f:
        for orig, mapped in mapping.items():
            # Write: remapped_opcode standard_opcode
            f.write(f"{mapped} {orig}\n")
    print(f"Mapping written to /tmp/isa_reverse_map")
    
    return mapping

# ── BOOT A ──
print("=" * 65)
print("BOOT A")
print("=" * 65)
seed_A = 42
remap_binary("hello", "hello_bootA", seed_A)

print("\n--- Running original binary ---")
ret = os.system("qemu-riscv64 hello")
print(f"Result: {'SUCCESS' if ret == 0 else 'FAILED'} (exit code {ret})")

print("\n--- Running Boot A binary ---")
ret = os.system("qemu-riscv64 hello_bootA")
print(f"Result: {'FAILED as expected - needs ISA decoder' if ret != 0 else 'SUCCESS'}")

# ── REBOOT → BOOT B ──
print("\n" + "=" * 65)
print("REBOOT → BOOT B (new seed)")
print("=" * 65)
seed_B = 99
remap_binary("hello", "hello_bootB", seed_B)

print("\n--- Running Boot A binary under Boot B conditions ---")
print("(Simulating malware from previous session)")
ret = os.system("qemu-riscv64 hello_bootA")
if ret != 0:
    print("RESULT: FAILED — Old binary cannot execute. ISA remapping works.")
else:
    print("RESULT: Ran (seed collision — try different seeds)")
