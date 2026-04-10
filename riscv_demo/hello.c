#include <stdint.h>

void _start() {
    // Simple infinite loop - bare metal, no OS needed
    volatile int x = 5;
    volatile int y = 10;
    volatile int z = x + y;
    
    // Exit via RISC-V ecall
    register long a0 asm("a0") = 0;
    register long a7 asm("a7") = 93;
    asm volatile("ecall" : : "r"(a0), "r"(a7));
}
