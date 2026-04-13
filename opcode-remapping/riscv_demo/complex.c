#include <stdint.h>

// Simple write syscall for output
static void write_char(char c) {
    register long a0 asm("a0") = 1;        // fd = stdout
    register long a1 asm("a1") = (long)&c; // buffer
    register long a2 asm("a2") = 1;        // length
    register long a7 asm("a7") = 64;       // syscall write
    asm volatile("ecall" : : "r"(a0),"r"(a1),"r"(a2),"r"(a7));
}

static void write_str(const char *s) {
    while (*s) write_char(*s++);
}

static int add(int a, int b) {
    return a + b;
}

static int multiply(int a, int b) {
    int result = 0;
    for (int i = 0; i < b; i++) {
        result = add(result, a);
    }
    return result;
}

void _start() {
    // Test 1: arithmetic
    volatile int x = multiply(6, 7);  // should be 42

    // Test 2: array
    volatile int arr[5];
    for (int i = 0; i < 5; i++) {
        arr[i] = multiply(i, i);  // 0,1,4,9,16
    }

    // Test 3: string output
    write_str("ISA Remap: OK\n");

    // Exit
    register long a0 asm("a0") = 0;
    register long a7 asm("a7") = 93;
    asm volatile("ecall" : : "r"(a0), "r"(a7));
}
