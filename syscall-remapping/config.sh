#!/bin/bash
# Phase 3 Config Loader — reads isa.env, resolves paths
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$BASE_DIR/isa.env"

while IFS='=' read -r key val; do
    [[ "$key" =~ ^#.*$ || -z "$key" ]] && continue
    key="${key// /}"; val="${val// /}"
    declare "$key=$val"
done < "$ENV_FILE"

export ISA_SYSCALL_KEYRING="$ISA_SYSCALL_KEYRING"
QEMU="$BASE_DIR/$QEMU_REL"
PHASE1="$BASE_DIR/$PHASE1_REL"
DEMO_DIR="$BASE_DIR/$DEMO_DIR_REL"
SYSCALL_REWRITER="$BASE_DIR/isa_syscall_rewrite.py"
SYSCALL_MAPPING_H="$BASE_DIR/syscall_mapping.h"
QEMU_SYSCALL_C="$PHASE1/qemu-8.2.0/linux-user/syscall.c"
QEMU_SYSCALL_H_DEST="$PHASE1/qemu-8.2.0/linux-user/syscall_mapping.h"
