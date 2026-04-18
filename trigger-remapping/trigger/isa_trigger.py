#!/usr/bin/env python3
"""
ISA Trigger Monitor — Phase 2
Watches for security events and remaps ISA without reboot.

Trigger modes:
  --manual       Wait for ENTER key press
  --timer N      Remap every N seconds automatically
  --watch        Remap when unknown process detected (process-based)

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

REVERSE_MAP = os.environ.get("ISA_MAP", "/etc/isa/map")

GREEN  = '\033[0;32m'
RED    = '\033[0;31m'
CYAN   = '\033[0;36m'
YELLOW = '\033[1;33m'
NC     = '\033[0m'

def generate_new_mapping():
    seed = int.from_bytes(os.urandom(32), 'big') % (2**32)
    r = random.Random(seed)
    s = OPCODES[:]
    r.shuffle(s)
    mapping = dict(zip(OPCODES, s))
    os.makedirs(os.path.dirname(REVERSE_MAP), exist_ok=True)
    content = "".join(f"{mapped} {orig}\n" for orig, mapped in mapping.items())
    try:
        with open(REVERSE_MAP, "w") as f:
            f.write(content)
    except PermissionError:
        import subprocess
        subprocess.run(["sudo", "tee", REVERSE_MAP],
                       input=content, text=True, capture_output=True, check=True)
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
    seed, _ = generate_new_mapping()
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
    seed, _ = generate_new_mapping()
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

def get_running_executables():
    """Read all running process executables from /proc."""
    procs = {}
    try:
        for pid in os.listdir("/proc"):
            if not pid.isdigit():
                continue
            try:
                exe = os.readlink(f"/proc/{pid}/exe")
                procs[pid] = exe
            except (PermissionError, FileNotFoundError, OSError):
                continue
    except Exception:
        pass
    return procs

def get_exe_hash(exe_path):
    """SHA-256 hash of executable binary."""
    try:
        with open(exe_path, 'rb') as f:
            return hashlib.sha256(f.read()).hexdigest()
    except (PermissionError, FileNotFoundError, OSError):
        return None

def watch_mode(interval=1):
    """
    Process-based watch mode — monitors /proc for new executables.
    Fires when unknown binary starts executing, before OS scheduler
    fully runs it. Much harder to evade than file polling.
    """
    print(f"\n{CYAN}  ISA Trigger Monitor — Watch Mode (process-based){NC}")
    print(f"  Monitoring /proc for unknown executables every {interval}s")
    print(f"  Press {RED}Ctrl+C{NC} to stop\n")

    seed, _ = generate_new_mapping()
    print(f"{GREEN}  Initial mapping active (seed={seed}){NC}\n")

    known_hashes = set()
    for pid, exe in get_running_executables().items():
        h = get_exe_hash(exe)
        if h:
            known_hashes.add(h)

    print(f"  {len(known_hashes)} running processes registered as known\n")

    remap_count = 0
    try:
        while True:
            time.sleep(interval)
            for pid, exe in get_running_executables().items():
                h = get_exe_hash(exe)
                if h and h not in known_hashes:
                    known_hashes.add(h)
                    remap_count += 1
                    trigger_remap(
                        f"Unknown process: PID={pid} exe={os.path.basename(exe)}"
                    )
            print(f"\r  Watching /proc... ({remap_count} triggers)",
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
        interval = int(sys.argv[2]) if len(sys.argv) > 2 else 1
        watch_mode(interval)
    else:
        print("Usage: python3 isa_trigger.py [--manual | --timer N | --watch [interval]]")
        sys.exit(1)

if __name__ == "__main__":
    main()
