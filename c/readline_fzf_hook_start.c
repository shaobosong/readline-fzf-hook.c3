#include <stddef.h>
#include <sys/syscall.h>
#include <sys/mman.h>
#include <assert.h>

#define hidden __attribute__((__visibility__("hidden")))

#define START "readline_fzf_hook_start"
#include "entry_arch.h"
#include "syscall_arch.h"

hidden void __exit(int status)
{
    do_syscall_1(__NR_exit, status);
    assert(0);
}

hidden void *_mmap(size_t length)
{
    return (void *)do_syscall_6(__NR_mmap, 0, length, PROT_READ | PROT_WRITE,
                                MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
}

hidden int _munmap(void *addr, size_t length) {
    return (int)do_syscall_2(__NR_munmap, (long)addr, length);
}

hidden int _execve(char *path, char *const argv[], char *const envp[])
{
    return (int)do_syscall_3(__NR_execve, (long)path, (long)argv, (long)envp);
}

hidden long _write(int fd, const char *buf, size_t count)
{
    return do_syscall_3(__NR_write, fd, (long)buf, count);
}

hidden size_t strlen_custom(const char *s)
{
    size_t i = 0;
    while (s[i]) {
        i++;
    }
    return i;
}

hidden void *memcpy_custom(void *dest, const void *src, size_t n)
{
    char *d = dest;
    const char *s = src;
    for (size_t i = 0; i < n; i++) {
        d[i] = s[i];
    }
    return dest;
}

hidden char *strchrnul_custom(const char *s, char c) {
    while (*s && *s != c) {
        s++;
    }
    return (char *)s;
}

hidden int str_starts_with(const char *str, const char *prefix) {
    while (*prefix) {
        if (*prefix++ != *str++) return 0;
    }
    return 1;
}

hidden void print_error(const char *msg) {
    if (msg) {
        (void)_write(2, msg, strlen_custom(msg));
    }
}

#define LD_PRELOAD_PREFIX "LD_PRELOAD="

hidden void readline_fzf_hook_start_c(size_t *sp, size_t *dynv)
{
    int argc = *sp;
    char **argv = (char **)(sp + 1);
    char **envp = &argv[argc + 1];
    char **e;
    int env_count;
    const char *path_env;
    char *libso = argv[0];
    size_t prefix_len;
    size_t libso_len;
    size_t prefix_libso_len;
    char *prefix_libso_env;
    char *target_prog = argv[1];
    char **target_argv = argv + 1;
    char **new_envp;
    size_t target_prog_len;
    const char *p_start;
    const char *p_end;
    size_t dir_len;
    char *target_path_prog;

    if (argc < 2) {
        print_error("Usage: ./readline_fzf_hook.so <program> [args...]\n");
        __exit(1);
    }

    for (e = envp, env_count = 0, path_env = NULL; *e; e++) {
        env_count++;
        if (str_starts_with(*e, "PATH=")) {
            path_env = *e + 5;
        }
    }

    prefix_len = sizeof(LD_PRELOAD_PREFIX) - 1;
    libso_len = strlen_custom(libso);
    prefix_libso_len = prefix_len + libso_len;

    prefix_libso_env = _mmap(prefix_libso_len + 1);
    if (prefix_libso_env == MAP_FAILED) {
        print_error("Error: Failed to allocate memory.\n");
        __exit(127);
    }

    memcpy_custom(prefix_libso_env, LD_PRELOAD_PREFIX, prefix_len);
    memcpy_custom(prefix_libso_env + prefix_len, libso, libso_len);
    prefix_libso_env[prefix_libso_len] = '\0';

    new_envp = _mmap((env_count + 2) * sizeof(char *));
     if (new_envp == MAP_FAILED) {
        print_error("Error: Failed to allocate memory.\n");
        __exit(127);
    }

    memcpy_custom(new_envp, envp, env_count * sizeof(char *));
    new_envp[env_count] = prefix_libso_env;
    new_envp[env_count + 1] = NULL;

    if (*strchrnul_custom(target_prog, '/')) {
        _execve(target_prog, target_argv, new_envp);
        print_error("Error: Failed to run program.\n");
        __exit(126);
    }

    if (!path_env) {
        print_error("Error: Failed to find `PATH`.\n");
        __exit(1);
    }

    target_prog_len = strlen_custom(target_prog);

    p_start = path_env;
    while (*p_start) {
        p_end = strchrnul_custom(p_start, ':');

        dir_len = p_end - p_start;
        if (dir_len <= 0) {
            break;
        }

        target_path_prog = _mmap(dir_len + 1 + target_prog_len + 1);
        if (target_path_prog == MAP_FAILED) {
            print_error("Error: Failed to allocate memory.\n");
            __exit(127);
        }

        memcpy_custom(target_path_prog, p_start, dir_len);
        target_path_prog[dir_len] = '/';
        memcpy_custom(target_path_prog + dir_len + 1, target_prog, target_prog_len);
        target_path_prog[dir_len + 1 + target_prog_len] = '\0';

        _execve(target_path_prog, target_argv, new_envp);

        if (_munmap(target_path_prog, dir_len + 1 + target_prog_len + 1) == -1) {
            print_error("Error: Failed to deallocate memory.\n");
            __exit(127);
        }

        if (!*p_end) {
            break;
        }

        p_start = p_end + 1;
    }

    print_error("Error: Failed to run program.\n");
    __exit(126);
}
