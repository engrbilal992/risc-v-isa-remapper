# RISC-V Register Remapping — Changelog

## Phase 3 Milestone 2 — Register Rewriter + Fingerprint Verification

### April 2026

#### Initial Release
- `isa_register_rewrite.py` — rewrites 5-bit rd/rs1/rs2 fields in ELF .text
  - OPCODE_FIELDS table: S/B-type rd and U/J-type rs2 are immediates, not remapped
  - Frozen registers: x0(zero), x1(ra), x2(sp), x10-x17(a0-a7) — never remapped
  - Embeds 24-bit fingerprint (2 addi x0,x0,N NOPs) at .text+0/+4
  - secrets.token_bytes(32) for 256-bit entropy random seeds
  - sudo tee fallback for 640 root-owned keyring files

- `register_mapping.h` — QEMU translate.c hook
  - mtime-reload pattern, no initialized flag (mtime=0 handles first load)
  - OPCODE_FIELDS table matches rewriter exactly (Curtis fix)
  - Fingerprint verification: reads FP line from keyring, checks binary NOPs
  - Standard binary (no fingerprint) → SIGILL → blocked
  - Wrong-seed binary (wrong fingerprint) → SIGILL → blocked
  - Correct-seed binary → register reverse-map applied → runs correctly

- `build.sh` — portable QEMU build, register patch only
  - No syscall patch, no opcode patch — clean separation from M1
  - /etc/isa/register_keyring (640 root:user)

- `audit.sh` — 11 live checks + static verification
- `demo.sh` — full security proof with fingerprint blocking
- POC limitation: -march=rv64g required, assembly test binaries with placeholder NOPs
