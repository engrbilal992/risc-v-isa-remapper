#ifndef SYSCALL_MAPPING_H
#define SYSCALL_MAPPING_H
#include <stdint.h>
#include <stdio.h>
#include <sys/stat.h>

#ifndef SYSCALL_KEYRING_PATH
#define SYSCALL_KEYRING_PATH "/etc/isa/syscall_keyring"
#endif

#define SYSCALL_COUNT 436

static int syscall_reverse_map[SYSCALL_COUNT];
static time_t syscall_map_mtime = 0;
static int syscall_map_initialized = 0;

static void syscall_mapping_reload(void)
{
    struct stat st;
    if (stat(SYSCALL_KEYRING_PATH, &st) != 0) return;
    if (syscall_map_initialized && st.st_mtime == syscall_map_mtime) return;

    /* Identity map by default */
    for (int i = 0; i < SYSCALL_COUNT; i++)
        syscall_reverse_map[i] = i;

    FILE *f = fopen(SYSCALL_KEYRING_PATH, "r");
    if (!f) return;

    int permuted, standard;
    while (fscanf(f, "%d %d", &permuted, &standard) == 2) {
        if (permuted >= 0 && permuted < SYSCALL_COUNT &&
            standard >= 0 && standard < SYSCALL_COUNT) {
            syscall_reverse_map[permuted] = standard;
        }
    }
    fclose(f);
    /* Update mtime only after successful read — fixes race condition */
    syscall_map_mtime = st.st_mtime;
    syscall_map_initialized = 1;
}

static inline int syscall_translate(int num)
{
    if (num < 0 || num >= SYSCALL_COUNT) return num;
    syscall_mapping_reload();
    return syscall_reverse_map[num];
}

#endif /* SYSCALL_MAPPING_H */
