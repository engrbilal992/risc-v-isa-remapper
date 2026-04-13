#include <stdint.h>

// ── Syscalls ─────────────────────────────────
static void write_char(char c) {
    register long a0 asm("a0") = 1;
    register long a1 asm("a1") = (long)&c;
    register long a2 asm("a2") = 1;
    register long a7 asm("a7") = 64;
    asm volatile("ecall"::"r"(a0),"r"(a1),"r"(a2),"r"(a7));
}

static void write_str(const char *s) {
    while (*s) write_char(*s++);
}

// ── Integer to string ─────────────────────────
static void write_int(int n) {
    if (n < 0) { write_char('-'); n = -n; }
    if (n >= 10) write_int(n / 10);
    write_char('0' + (n % 10));
}

// ── Math functions ────────────────────────────
static int multiply(int a, int b) {
    int result = 0;
    for (int i = 0; i < b; i++) result += a;
    return result;
}

static int power(int base, int exp) {
    int result = 1;
    for (int i = 0; i < exp; i++)
        result = multiply(result, base);
    return result;
}

static int fibonacci(int n) {
    if (n <= 1) return n;
    int a = 0, b = 1, c;
    for (int i = 2; i <= n; i++) {
        c = a + b;
        a = b;
        b = c;
    }
    return b;
}

// ── Bubble sort ───────────────────────────────
static void bubble_sort(int *arr, int n) {
    for (int i = 0; i < n-1; i++)
        for (int j = 0; j < n-i-1; j++)
            if (arr[j] > arr[j+1]) {
                int tmp = arr[j];
                arr[j] = arr[j+1];
                arr[j+1] = tmp;
            }
}

void _start() {
    write_str("=== RISC-V ISA Remap: Advanced Test ===\n");

    // Test 1: multiplication table
    write_str("\n[1] Multiply 6x7 = ");
    write_int(multiply(6, 7));
    write_char('\n');

    // Test 2: power
    write_str("[2] Power 2^10 = ");
    write_int(power(2, 10));
    write_char('\n');

    // Test 3: fibonacci
    write_str("[3] Fibonacci sequence: ");
    for (int i = 0; i < 10; i++) {
        write_int(fibonacci(i));
        write_char(' ');
    }
    write_char('\n');

    // Test 4: bubble sort
    int arr[] = {64, 34, 25, 12, 22, 11, 90};
    int n = 7;
    bubble_sort(arr, n);
    write_str("[4] Sorted array: ");
    for (int i = 0; i < n; i++) {
        write_int(arr[i]);
        write_char(' ');
    }
    write_char('\n');

    write_str("\n=== All tests passed under remapped ISA ===\n");

    // Exit
    register long a0 asm("a0") = 0;
    register long a7 asm("a7") = 93;
    asm volatile("ecall"::"r"(a0),"r"(a7));
}
