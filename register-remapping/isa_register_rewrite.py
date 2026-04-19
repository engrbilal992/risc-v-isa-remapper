#!/usr/bin/env python3
"""
ISA Register Rewriter — Phase 3 Milestone 2
Rewrites 5-bit register fields (rd, rs1, rs2) in RISC-V ELF .text section.

OPCODE_FIELDS table ensures only actual register fields are rewritten.
S/B-type rd bits are immediates — never rewritten.
U/J-type rs2 bits are immediates — never rewritten.

Frozen registers (never remapped — ABI boundary):
  x0(zero), x1(ra), x2(sp), x10-x17(a0-a7) = 11 frozen, 21 shuffleable
  Entropy: 21! ≈ 2^65

POC Limitation: -march=rv64g required (no RVC compressed instructions).

Author: Muhammad Bilal
Usage: python3 isa_register_rewrite.py <input> <output> [--seed N] [--keyring P] [--quiet]
"""

import sys, os, struct, random, secrets, argparse, shutil, subprocess

REG_COUNT    = 32
KEYRING_PATH = os.environ.get("REGISTER_KEYRING", "/etc/isa/register_keyring")

import hashlib

# Fingerprint — embedded in binary to prove it was compiled under this permutation
FP_MAGIC = 0x00013  # addi x0, x0, N: bits[19:0] = 0x00013

def make_fingerprint(seed):
    """24-bit fingerprint from seed, split across 2 NOP instructions."""
    h = hashlib.sha256(str(seed).encode()).digest()
    fp = int.from_bytes(h[:3], 'big') & 0xFFFFFF
    return fp, (fp >> 12) & 0xFFF, fp & 0xFFF

def encode_fp_nop(val):
    """addi x0, x0, val — true NOP encoding fingerprint bits."""
    return ((val & 0xFFF) << 20) | FP_MAGIC

def embed_fingerprint(data, text_start, hi12, lo12):
    """Prepend 2 fingerprint NOPs at start of .text section."""
    import struct
    nop1 = encode_fp_nop(hi12)
    nop2 = encode_fp_nop(lo12)
    # Overwrite first 8 bytes of .text with fingerprint NOPs
    struct.pack_into("<I", data, text_start,     nop1)
    struct.pack_into("<I", data, text_start + 4, nop2)

def write_keyring_with_fingerprint(perm, seed, path=KEYRING_PATH):
    """Write keyring: first line is fingerprint, rest is reverse map."""
    fp, hi12, lo12 = make_fingerprint(seed)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    reverse = list(range(REG_COUNT))
    for std in range(REG_COUNT):
        reverse[perm[std]] = std
    lines = [f"FP {fp:06X}\n"]
    lines += [f"{permuted} {standard}\n"
              for permuted, standard in enumerate(reverse)
              if permuted != standard]
    content = "".join(lines)
    try:
        with open(path, "w") as f:
            f.write(content)
    except PermissionError:
        import subprocess
        r = subprocess.run(["sudo", "tee", path],
                           input=content, text=True, capture_output=True)
        if r.returncode != 0:
            raise PermissionError(f"Cannot write keyring: {r.stderr}")

# Frozen registers — ABI boundary, never remapped
# x0=zero, x1=ra, x2=sp, x10-x17=a0-a7
FROZEN      = {0, 1, 2, 10, 11, 12, 13, 14, 15, 16, 17}
SHUFFLEABLE = [r for r in range(REG_COUNT) if r not in FROZEN]  # 21 regs

# OPCODE_FIELDS: (has_rd, has_rs1, has_rs2) — True only if field is a real register.
# Curtis fix: S/B-type rd bits are immediate[4:0], U/J-type rs2 bits are immediate.
OPCODE_FIELDS = {
    # R-type: all three fields are registers
    0x33: (True,  True,  True),   # OP
    0x3B: (True,  True,  True),   # OP-32
    0x2F: (True,  True,  True),   # AMO
    0x53: (True,  True,  True),   # FP-OP
    0x43: (True,  True,  True),   # FMADD
    0x47: (True,  True,  True),   # FMSUB
    0x4B: (True,  True,  True),   # FNMSUB
    0x4F: (True,  True,  True),   # FNMADD
    # I-type: rd and rs1 are registers, rs2 bits are immediate
    0x13: (True,  True,  False),  # OP-IMM
    0x1B: (True,  True,  False),  # OP-IMM-32
    0x03: (True,  True,  False),  # LOAD
    0x67: (True,  True,  False),  # JALR
    0x07: (True,  True,  False),  # FP-LOAD
    0x0F: (False, True,  False),  # FENCE (rd=0 by convention)
    # S-type: rs1 and rs2 are registers, rd bits are immediate[4:0]
    0x23: (False, True,  True),   # STORE
    0x27: (False, True,  True),   # FP-STORE
    # B-type: rs1 and rs2 are registers, rd bits are immediate
    0x63: (False, True,  True),   # BRANCH
    # U-type: rd is register, rs1/rs2 bits are all immediate
    0x37: (True,  False, False),  # LUI
    0x17: (True,  False, False),  # AUIPC
    # J-type: rd is register, rs1/rs2 bits are all immediate
    0x6F: (True,  False, False),  # JAL
    # SYSTEM: never touch
    0x73: (False, False, False),  # ECALL/EBREAK/CSR
}

def generate_permutation(seed):
    """
    Deterministic register permutation from seed.
    random.Random() accepts arbitrarily large ints — no split path needed.
    Returns perm[standard] = permuted for shuffleable registers.
    Frozen registers always map to themselves.
    """
    r = random.Random(seed)
    shuffled = SHUFFLEABLE[:]
    r.shuffle(shuffled)
    perm = list(range(REG_COUNT))
    for std, p in zip(SHUFFLEABLE, shuffled):
        perm[std] = p
    return perm

def write_keyring(perm, path=KEYRING_PATH):
    """
    Write reverse map: permuted standard
    QEMU reads permuted index, maps back to standard.
    Only write non-identity entries (frozen regs not written).
    sudo tee fallback for 640 root-owned files.
    """
    os.makedirs(os.path.dirname(path), exist_ok=True)
    # Reverse: for each permuted index, what standard reg does it correspond to?
    reverse = list(range(REG_COUNT))
    for std in range(REG_COUNT):
        reverse[perm[std]] = std
    lines = [f"{permuted} {standard}\n"
             for permuted, standard in enumerate(reverse)
             if permuted != standard]
    content = "".join(lines)
    try:
        with open(path, "w") as f:
            f.write(content)
    except PermissionError:
        r = subprocess.run(["sudo", "tee", path],
                           input=content, text=True, capture_output=True)
        if r.returncode != 0:
            raise PermissionError(f"Cannot write keyring: {r.stderr}")

def get_text_section(data):
    if len(data) < 64 or data[:4] != b'\x7fELF':
        return 0, len(data)
    e_shoff     = struct.unpack_from('<Q', data, 40)[0]
    e_shentsize = struct.unpack_from('<H', data, 58)[0]
    e_shnum     = struct.unpack_from('<H', data, 60)[0]
    e_shstrndx  = struct.unpack_from('<H', data, 62)[0]
    shstr_off      = e_shoff + e_shstrndx * e_shentsize
    shstr_file_off = struct.unpack_from('<Q', data, shstr_off + 24)[0]
    for i in range(e_shnum):
        sh_off      = e_shoff + i * e_shentsize
        sh_name     = struct.unpack_from('<I', data, sh_off)[0]
        sh_file_off = struct.unpack_from('<Q', data, sh_off + 24)[0]
        sh_size     = struct.unpack_from('<Q', data, sh_off + 32)[0]
        name = b''
        j = shstr_file_off + sh_name
        while j < len(data) and data[j] != 0:
            name += bytes([data[j]]); j += 1
        if name == b'.text':
            return sh_file_off, sh_file_off + sh_size
    return 0, len(data)

def rewrite_binary(input_file, output_file, perm, quiet=False):
    shutil.copy(input_file, output_file)
    os.chmod(output_file, 0o755)
    with open(output_file, "rb") as f:
        data = bytearray(f.read())
    text_start, text_end = get_text_section(data)
    if not quiet:
        print(f"[REG] .text: 0x{text_start:X} - 0x{text_end:X}")
    count = 0
    i = text_start
    while i <= text_end - 4:
        word = struct.unpack_from("<I", data, i)[0]
        if (word & 0x3) != 0x3:   # skip 16-bit compressed
            i += 2; continue
        opcode = word & 0x7F
        if opcode not in OPCODE_FIELDS:
            i += 4; continue
        has_rd, has_rs1, has_rs2 = OPCODE_FIELDS[opcode]
        new_word = word
        changed  = False
        if has_rd:
            rd = (word >> 7) & 0x1F
            nr = perm[rd]
            if nr != rd:
                new_word = (new_word & ~(0x1F << 7)) | (nr << 7)
                changed = True
        if has_rs1:
            rs1 = (word >> 15) & 0x1F
            nr  = perm[rs1]
            if nr != rs1:
                new_word = (new_word & ~(0x1F << 15)) | (nr << 15)
                changed = True
        if has_rs2:
            rs2 = (word >> 20) & 0x1F
            nr  = perm[rs2]
            if nr != rs2:
                new_word = (new_word & ~(0x1F << 20)) | (nr << 20)
                changed = True
        if changed:
            struct.pack_into("<I", data, i, new_word)
            count += 1
        i += 4
    with open(output_file, "wb") as f:
        f.write(data)
    if not quiet:
        print(f"[REG] Remapped {count} instructions -> {output_file}")
    return count

def rewrite_binary_with_fp(input_file, output_file, perm, seed, quiet=False):
    """Rewrite binary: remap registers AND embed fingerprint NOPs."""
    shutil.copy(input_file, output_file)
    os.chmod(output_file, 0o755)
    with open(output_file, "rb") as f:
        data = bytearray(f.read())
    text_start, text_end = get_text_section(data)
    if not quiet:
        print(f"[REG] .text: 0x{text_start:X} - 0x{text_end:X}")
    # Remap registers
    count = 0
    i = text_start + 8  # skip first 8 bytes reserved for fingerprint
    while i <= text_end - 4:
        word = struct.unpack_from("<I", data, i)[0]
        if (word & 0x3) != 0x3:
            i += 2; continue
        opcode = word & 0x7F
        if opcode not in OPCODE_FIELDS:
            i += 4; continue
        has_rd, has_rs1, has_rs2 = OPCODE_FIELDS[opcode]
        new_word = word
        changed = False
        if has_rd:
            rd = (word >> 7) & 0x1F
            nr = perm[rd]
            if nr != rd:
                new_word = (new_word & ~(0x1F << 7)) | (nr << 7)
                changed = True
        if has_rs1:
            rs1 = (word >> 15) & 0x1F
            nr = perm[rs1]
            if nr != rs1:
                new_word = (new_word & ~(0x1F << 15)) | (nr << 15)
                changed = True
        if has_rs2:
            rs2 = (word >> 20) & 0x1F
            nr = perm[rs2]
            if nr != rs2:
                new_word = (new_word & ~(0x1F << 20)) | (nr << 20)
                changed = True
        if changed:
            struct.pack_into("<I", data, i, new_word)
            count += 1
        i += 4
    # Embed fingerprint at start of .text
    fp, hi12, lo12 = make_fingerprint(seed)
    embed_fingerprint(data, text_start, hi12, lo12)
    with open(output_file, "wb") as f:
        f.write(data)
    if not quiet:
        print(f"[REG] Fingerprint: 0x{fp:06X} embedded at .text+0")
        print(f"[REG] Remapped {count} instructions -> {output_file}")
    return count

def main():
    parser = argparse.ArgumentParser(description="RISC-V Register Rewriter")
    parser.add_argument("input")
    parser.add_argument("output")
    parser.add_argument("--seed",    type=int, default=None)
    parser.add_argument("--keyring", default=KEYRING_PATH)
    parser.add_argument("--quiet",   action="store_true")
    args = parser.parse_args()

    if args.seed is not None:
        seed = args.seed
        seed_display = str(seed)
    else:
        seed_bytes = secrets.token_bytes(32)
        seed = int.from_bytes(seed_bytes, 'big')
        seed_display = seed_bytes.hex()[:16] + "..."

    if not args.quiet:
        print(f"\n{'='*60}")
        print(f"  RISC-V Register Rewriter — Phase 3 Milestone 2")
        print(f"{'='*60}")
        print(f"  Input  : {args.input}")
        print(f"  Output : {args.output}")
        print(f"  Seed   : {seed_display}")
        print(f"  Keyring: {args.keyring}")
        print(f"  Frozen : x0,x1,x2,x10-x17 (11 regs)")
        print(f"  Shuffle: {len(SHUFFLEABLE)} regs — keyspace 21! ≈ 2^65")

    perm = generate_permutation(seed)
    write_keyring_with_fingerprint(perm, seed, args.keyring)

    if not args.quiet:
        print(f"[REG] Keyring -> {args.keyring}")

    count = rewrite_binary_with_fp(args.input, args.output, perm, seed, args.quiet)

    if not args.quiet:
        print(f"\n  Remapped {count} instruction(s)")
        print(f"{'='*60}\n")

if __name__ == "__main__":
    main()
