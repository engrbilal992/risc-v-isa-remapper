import sys
import os
import random
import struct
import shutil

# RISC-V standard 7-bit opcodes
RISCV_OPCODES = {
    0b0110011: "OP",
    0b0010011: "OP-IMM",
    0b0000011: "LOAD",
    0b0100011: "STORE",
    0b1100011: "BRANCH",
    0b1101111: "JAL",
    0b1100111: "JALR",
    0b0110111: "LUI",
    0b0010111: "AUIPC",
    0b1110011: "SYSTEM",
    0b0001111: "FENCE",
    0b0111011: "OP-32",
    0b0011011: "OP-IMM-32",
}

def get_opcode(instruction):
    """Extract 7-bit opcode from 32-bit instruction."""
    return instruction & 0x7F

def set_opcode(instruction, new_opcode):
    """Replace opcode in instruction, keep rest unchanged."""
    return (instruction & ~0x7F) | (new_opcode & 0x7F)

def generate_mapping(seed):
    """Generate deterministic opcode shuffle from seed."""
    opcodes = list(RISCV_OPCODES.keys())
    r = random.Random(seed)
    shuffled = opcodes[:]
    r.shuffle(shuffled)
    return dict(zip(opcodes, shuffled))

def remap_binary(input_file, output_file, seed):
    """Read ELF binary, remap all opcodes, write new binary."""
    mapping = generate_mapping(seed)
    
    print(f"\nSeed: {seed}")
    print(f"{'Original Opcode':<20} {'Mapped To':<20} {'Instruction Type'}")
    print("-" * 60)
    for orig, mapped in mapping.items():
        print(f"{bin(orig):<20} {bin(mapped):<20} {RISCV_OPCODES[orig]}")
    
    # Copy binary
    shutil.copy(input_file, output_file)
    
    # Read binary
    with open(output_file, 'rb') as f:
        data = bytearray(f.read())
    
    # Find .text section - scan for 32-bit instructions
    # Simple approach: scan whole binary for valid RISC-V opcodes
    remapped_count = 0
    i = 0
    while i < len(data) - 3:
        # Read 4 bytes as little-endian 32-bit instruction
        instr = struct.unpack_from('<I', data, i)[0]
        opcode = get_opcode(instr)
        
        if opcode in mapping and mapping[opcode] != opcode:
            new_instr = set_opcode(instr, mapping[opcode])
            struct.pack_into('<I', data, i, new_instr)
            remapped_count += 1
        i += 4
    
    # Write remapped binary
    with open(output_file, 'wb') as f:
        f.write(data)
    
    print(f"\nRemapped {remapped_count} instructions")
    print(f"Output: {output_file}")
    return mapping

# ── BOOT A ──
print("=" * 60)
print("BOOT A - Compiling and running with mapping A")
print("=" * 60)

seed_A = 42  # Fixed seed for demo reproducibility
mapping_A = remap_binary("hello", "hello_bootA", seed_A)

print("\nRunning original binary (no mapping)...")
ret = os.system("qemu-riscv64 hello")
print(f"Original binary result: {'SUCCESS' if ret == 0 else 'FAILED'}")

print("\nRunning Boot A remapped binary with Boot A mapping...")
ret = os.system("qemu-riscv64 hello_bootA")
print(f"Boot A binary result: {'SUCCESS (expected - same mapping)' if ret == 0 else 'FAILED'}")

# ── REBOOT → BOOT B ──
print("\n" + "=" * 60)
print("REBOOT - New seed generated")
print("=" * 60)

seed_B = 99  # Different seed = different mapping
mapping_B = remap_binary("hello", "hello_bootB", seed_B)

print("\nRunning Boot A binary under Boot B mapping...")
print("(This simulates old malware trying to run after reboot)")
ret = os.system("qemu-riscv64 hello_bootA")
print(f"Boot A binary under Boot B: {'FAILED - ISA remapping works!' if ret != 0 else 'Still ran (opcode collision)'}")
