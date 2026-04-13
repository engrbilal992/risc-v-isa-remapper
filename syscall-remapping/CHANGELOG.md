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

### [2026-04-13] Portability improvements
- build.sh now fully portable — downloads QEMU 8.2.0 on clean machine
- Applies both opcode patch (isa_mapping.h) and syscall patch automatically
- Creates qemu-riscv64 symlink in phase3 directory
- config.sh uses symlink if present, relative path otherwise
- complex.c expanded: tests write(64), exit(93), getpid(172), brk(214)
- isa_mapping.h copied into phase3 for self-contained deployment
- 38/38 audit checks pass
