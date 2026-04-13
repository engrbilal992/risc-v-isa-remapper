# RISC-V ISA Remapping — Phase 3 Changelog

## Milestone 1 — Syscall Rewriter + QEMU ecall Hook

### [2026-04-13] Initial implementation
- `isa_syscall_rewrite.py` — rewrites li a7,N sequences in ELF .text section
- `syscall_mapping.h` — QEMU ecall hook with mtime-reload pattern
- `build.sh` — auto-copies header into QEMU tree, checksums before make
- `demo.sh` — full demo: simple and complex binaries under two permutations
- `audit.sh` — automated checks
- Keyring: /etc/isa/syscall_keyring, 0600 permissions
- POC limitation: static binaries only, no dynamic syscall computation
