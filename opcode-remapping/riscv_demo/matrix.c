#include <stdint.h>

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

static void write_int(int n) {
    if (n < 0) { write_char('-'); n = -n; }
    if (n >= 10) write_int(n / 10);
    write_char('0' + (n % 10));
}

#define N 3

void matrix_multiply(int A[N][N], int B[N][N], int C[N][N]) {
    for (int i = 0; i < N; i++)
        for (int j = 0; j < N; j++) {
            C[i][j] = 0;
            for (int k = 0; k < N; k++)
                C[i][j] += A[i][k] * B[k][j];
        }
}

void _start() {
    int A[N][N] = {{1,2,3},{4,5,6},{7,8,9}};
    int B[N][N] = {{9,8,7},{6,5,4},{3,2,1}};
    int C[N][N] = {0};

    matrix_multiply(A, B, C);

    write_str("=== Matrix Multiplication ===\n");
    for (int i = 0; i < N; i++) {
        write_str("[ ");
        for (int j = 0; j < N; j++) {
            write_int(C[i][j]);
            write_char(' ');
        }
        write_str("]\n");
    }
    write_str("=== Done ===\n");

    register long a0 asm("a0") = 0;
    register long a7 asm("a7") = 93;
    asm volatile("ecall"::"r"(a0),"r"(a7));
}
