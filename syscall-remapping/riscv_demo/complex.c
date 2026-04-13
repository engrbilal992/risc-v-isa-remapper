/* complex.c — bare-metal RISC-V: multiple syscalls */
static long do_syscall1(long num, long a) {
    register long r_a0 asm("a0") = a;
    register long r_a7 asm("a7") = num;
    asm volatile("ecall" : "+r"(r_a0) : "r"(r_a7) : "memory");
    return r_a0;
}

static long do_syscall3(long num, long a, long b, long c) {
    register long r_a0 asm("a0") = a;
    register long r_a1 asm("a1") = b;
    register long r_a2 asm("a2") = c;
    register long r_a7 asm("a7") = num;
    asm volatile("ecall" : "+r"(r_a0) : "r"(r_a1),"r"(r_a2),"r"(r_a7) : "memory");
    return r_a0;
}

static void write_str(const char *s) {
    int len = 0;
    while (s[len]) len++;
    do_syscall3(64, 1, (long)s, len);  /* write */
}

void _start(void) {
    write_str("SYSCALL REMAP: complex test start\n");
    write_str("SYSCALL REMAP: multiple syscalls OK\n");
    write_str("SYSCALL REMAP: complex test PASSED\n");
    do_syscall1(93, 0);  /* exit */
}
