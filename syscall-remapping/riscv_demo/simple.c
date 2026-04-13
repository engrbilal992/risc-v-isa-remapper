/* simple.c — bare-metal RISC-V: write + exit only */
static void write_str(const char *s) {
    int len = 0;
    while (s[len]) len++;
    register long a0 asm("a0") = 1;        /* fd = stdout */
    register long a1 asm("a1") = (long)s;  /* buf */
    register long a2 asm("a2") = len;      /* count */
    register long a7 asm("a7") = 64;       /* syscall: write */
    asm volatile("ecall" : : "r"(a0),"r"(a1),"r"(a2),"r"(a7) : "memory");
}

void _start(void) {
    write_str("SYSCALL REMAP: simple write test OK\n");
    register long a0 asm("a0") = 0;
    register long a7 asm("a7") = 93;       /* syscall: exit */
    asm volatile("ecall" : : "r"(a0),"r"(a7));
}
