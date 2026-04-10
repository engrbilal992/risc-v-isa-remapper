#!/usr/bin/env python3
"""
ISA Trigger Monitor — Phase 2
Watches for security events and remaps ISA without reboot.

Trigger modes:
  --manual       Wait for ENTER key press
  --timer N      Remap every N seconds automatically
  --watch <path> Remap when unknown binary detected

Author: Muhammad Bilal
"""

import sys
import os
import random
import time
import hashlib

OPCODES     = [0x33,0x13,0x03,0x23,0x63,0x6F,0x67,0x37,0x17,0x0F,0x3B,0x1B]
NAMES       = {
    0x33:"OP", 0x13:"OP-IMM", 0x03:"LOAD",
    0x23:"STORE", 0x63:"BRANCH", 0x6F:"JAL",
    0x67:"JALR", 0x37:"LUI", 0x17:"AUIPC",
    0x0F:"FENCE", 0x3B:"OP-32", 0x1B:"OP-IMM-32"
}

# FIX C1/C8: Read map path from env or use secure default
REVERSE_MAP = os.environ.get("ISA_MAP", "/etc/isa/map")

GREEN  = '\033[0;32m'
RED    = '\033[0;31m'
CYAN   = '\033[0;36m'
YELLOW = '\033[1;33m'
NC     = '\033[0m'

def generate_new_mapping():
    # FIX C5: Use os.urandom(32) for cryptographically secure seed
    seed = int.from_bytes(os.urandom(32), 'big') % (2**32)
    r = random.Random(seed)
    s = OPCODES[:]
    r.shuffle(s)
    mapping = dict(zip(OPCODES, s))

    # FIX B2: Remove f.write(str(seed)) — was corrupting fscanf parsing
    os.makedirs(os.path.dirname(REVERSE_MAP), exist_ok=True)
    with open(REVERSE_MAP, "w") as f:
        for orig, mapped in mapping.items():
            f.write(f"{mapped} {orig}\n")
        # NO seed write here — was breaking QEMU fscanf

    return seed, mapping

def print_mapping(seed, mapping):
    print(f"\n{CYAN}  New ISA Mapping (seed={seed}):{NC}")
    print(f"  {'Original':^16} {'Remapped':^16}")
    print(f"  {'-'*34}")
    for o, m in mapping.items():
        changed = " *" if o != m else ""
        print(f"  0x{o:02X} ({NAMES[o]:<10}) -> 0x{m:02X}{changed}")
    print(f"  {GREEN}Reverse map written -> {REVERSE_MAP}{NC}\n")

def trigger_remap(reason):
    print(f"\n{RED}[TRIGGER] {reason}{NC}")
    print(f"{YELLOW}  Generating new ISA mapping...{NC}")
    seed, mapping = generate_new_mapping()
    print_mapping(seed, mapping)
    print(f"{GREEN}  ISA remapped. All old binaries now invalid.{NC}\n")
    return seed

def manual_mode():
    print(f"\n{CYAN}  ISA Trigger Monitor — Manual Mode{NC}")
    print(f"  Press {YELLOW}ENTER{NC} to trigger | {RED}Ctrl+C{NC} to exit\n")
    seed, mapping = generate_new_mapping()
    print(f"{GREEN}  Initial mapping active (seed={seed}){NC}")
    remap_count = 0
    try:
        while True:
            input(f"\n  [{remap_count} remaps done] Press ENTER to remap ISA... ")
            remap_count += 1
            trigger_remap(f"Manual trigger #{remap_count}")
    except KeyboardInterrupt:
        print(f"\n{YELLOW}  Monitor stopped. {remap_count} remaps done.{NC}")

def timer_mode(interval):
    print(f"\n{CYAN}  ISA Trigger Monitor — Timer Mode (every {interval}s){NC}")
    print(f"  Press {RED}Ctrl+C{NC} to stop\n")
    seed, mapping = generate_new_mapping()
    print(f"{GREEN}  Initial mapping active (seed={seed}){NC}\n")
    remap_count = 0
    try:
        while True:
            for remaining in range(interval, 0, -1):
                print(f"\r  Next remap in {remaining}s... ", end="", flush=True)
                time.sleep(1)
            remap_count += 1
            trigger_remap(f"Timer trigger #{remap_count} (every {interval}s)")
    except KeyboardInterrupt:
        print(f"\n{YELLOW}  Monitor stopped. {remap_count} remaps done.{NC}")

def watch_mode(watch_path):
    print(f"\n{CYAN}  ISA Trigger Monitor — Watch Mode{NC}")
    print(f"  Watching: {watch_path} | {RED}Ctrl+C{NC} to stop\n")
    seed, mapping = generate_new_mapping()
    print(f"{GREEN}  Initial mapping active (seed={seed}){NC}\n")

    known_hashes = set()

    def get_hash(filepath):
        # FIX C6: Use SHA-256 instead of MD5
        try:
            with open(filepath, 'rb') as f:
                return hashlib.sha256(f.read()).hexdigest()
        except:
            return None

    if os.path.isdir(watch_path):
        for fname in os.listdir(watch_path):
            h = get_hash(os.path.join(watch_path, fname))
            if h:
                known_hashes.add(h)
    print(f"  {len(known_hashes)} existing files registered as known\n")

    remap_count = 0
    try:
        while True:
            time.sleep(2)
            if os.path.isdir(watch_path):
                for fname in os.listdir(watch_path):
                    fpath = os.path.join(watch_path, fname)
                    h = get_hash(fpath)
                    if h and h not in known_hashes:
                        known_hashes.add(h)
                        remap_count += 1
                        trigger_remap(f"Unknown binary detected: {fname}")
            print(f"\r  Watching {watch_path}... ({remap_count} triggers)",
                  end="", flush=True)
    except KeyboardInterrupt:
        print(f"\n{YELLOW}  Monitor stopped. {remap_count} remaps done.{NC}")

def main():
    if len(sys.argv) < 2 or sys.argv[1] == "--manual":
        manual_mode()
    elif sys.argv[1] == "--timer":
        interval = int(sys.argv[2]) if len(sys.argv) > 2 else 10
        timer_mode(interval)
    elif sys.argv[1] == "--watch":
        path = sys.argv[2] if len(sys.argv) > 2 else "/tmp"
        watch_mode(path)
    else:
        print("Usage: python3 isa_trigger.py [--manual | --timer N | --watch <path>]")
        sys.exit(1)

if __name__ == "__main__":
    main()
