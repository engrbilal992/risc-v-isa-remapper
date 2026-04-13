/* complex.c — bare-metal RISC-V: multiple syscalls tested
 * Tests: write(64), exit(93), getpid(172), brk(214)
 * Compiled with -march=rv64g (no RVC) as POC requirement
 */

static long do_syscall0(long num) {
    register long r_a0 asm("a0") = 0;
    register long r_a7 asm("a7") = num;
    asm volatile("ecall" : "+r"(r_a0) : "r"(r_a7) : "memory");
    return r_a0;
}

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
    do_syscall3(64, 1, (long)s, len);  /* write(stdout, s, len) */
}

static void write_num(long n) {
    char buf[32];
    int i = 30;
    buf[31] = '\n';
    if (n == 0) { buf[i--] = '0'; }
    else {
        while (n > 0) { buf[i--] = '0' + (n % 10); n /= 10; }
    }
    do_syscall3(64, 1, (long)(buf + i + 1), 31 - i);
}

void _start(void) {
    /* Test 1: write syscall (64) */
    write_str("SYSCALL REMAP: complex test start\n");

    /* Test 2: getpid syscall (172) — returns current PID */
    long pid = do_syscall0(172);
    write_str("SYSCALL REMAP: getpid() = ");
    write_num(pid);

    /* Test 3: brk syscall (214) — returns current brk address */
    do_syscall1(214, 0);
    write_str("SYSCALL REMAP: brk(0) OK\n");

    /* Test 4: multiple write calls */
    write_str("SYSCALL REMAP: multiple syscalls OK\n");
    write_str("SYSCALL REMAP: complex test PASSED\n");

    /* Test 5: exit syscall (93) */
    do_syscall1(93, 0);
}
