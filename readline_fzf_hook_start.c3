module readline_fzf_hook_start @private;

const long __NR_WRITE = 1;
const long __NR_MMAP = 9;
const long __NR_MUNMAP = 11;
const long __NR_EXECVE = 59;
const long __NR_EXIT = 60;
const long __NR_GETCWD = 79;

const long PROT_READ = 0x1;
const long PROT_WRITE = 0x2;

const long MAP_PRIVATE = 0X2;
const long MAP_ANONYMOUS = 0x20;
const void* MAP_FAILED = (void*)((usz)-1);

const int PATH_MAX = 1024;
const char[*] LD_PRELOAD_PREFIX = "LD_PRELOAD=";

fn long do_syscall_0(long n)
{
    ulong ret;
    asm {
        movq $rax, n;
        syscall;
        movq ret, $rax;
    }
    return ret;
}

fn long do_syscall_1(long n, long a1)
{
    ulong ret;
    asm {
        movq $rax, n;
        movq $rdi, a1;
        syscall;
        movq ret, $rax;
    }
    return ret;
}

fn long do_syscall_2(long n, long a1, long a2)
{
    ulong ret;
    asm {
        movq $rax, n;
        movq $rdi, a1;
        movq $rsi, a2;
        syscall;
        movq ret, $rax;
    }
    return ret;
}

fn long do_syscall_3(long n, long a1, long a2, long a3)
{
    ulong ret;
    asm {
        movq $rax, n;
        movq $rdi, a1;
        movq $rsi, a2;
        movq $rdx, a3;
        syscall;
        movq ret, $rax;
    }
    return 0;
}

fn long do_syscall_6(long n, long a1, long a2, long a3, long a4, long a5, long a6)
{
    ulong ret;
    asm {
        movq $rax, n;
        movq $rdi, a1;
        movq $rsi, a2;
        movq $rdx, a3;
        movq $r10, a4;
        movq $r8, a5;
        movq $r9, a6;
    }
    asm {
        syscall;
        movq ret, $rax;
    }
    return ret;
}

fn long _write(int fd, char *buf, usz count)
{
    return do_syscall_3(__NR_WRITE, fd, (long)buf, count);
}

fn void *_mmap(usz length)
{
    return (void *)do_syscall_6(__NR_MMAP, 0, length, PROT_READ | PROT_WRITE,
                                MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
}

fn int _munmap(void *addr, usz length)
{
    return (int)do_syscall_2(__NR_MUNMAP, (long)addr, length);
}

fn int _execve(char *path, char** argv, char** envp)
{
    return (int)do_syscall_3(__NR_EXECVE, (long)path, (long)argv, (long)envp);
}

fn void __exit(int status)
{
    do_syscall_1(__NR_EXIT, status);
}

fn long _getcwd(char *buf, ulong size)
{
    return do_syscall_2(__NR_GETCWD, (long)buf, size);
}

<*
 @require s != null
 @param [&in] s
*>
fn usz strlen_custom(char *s)
{
    usz i = 0;
    while (s[i]) {
        i++;
    }
    return i;
}

<*
 @require dest != null
 @require src != null
 @param [&in] src
*>
fn void *memcpy_custom(void *dest, void *src, usz n)
{
    char *d = dest;
    char *s = src;
    for (usz i = 0; i < n; i++) {
        d[i] = s[i];
    }
    return dest;
}

<*
 @require s != null
 @param [&in] s
*>
fn char *strchrnul_custom(char *s, char c)
{
    while (*s && *s != c) {
        s++;
    }
    return (void *)s;
}

<*
 @require s != null
 @param [&in] s
*>
fn char *strchr_custom(char *s, char c)
{
    while (*s && *s != c) {
        s++;
    }
    return *s == c ? (void *)s : null;
}

<*
 @require s != null
 @param [&in] s
*>
fn char *strrchr_custom(char *s, char c)
{
    usz n = strlen_custom(s) + 1;
    while (n--) {
        if (s[n] == c) {
            return (void *)(s + n);
        }
    }
    return null;
}

<*
 @require str != null
 @require prefix != null
 @param [&in] str
 @param [&in] prefix
*>
fn int str_starts_with(char *str, char *prefix)
{
    while (*prefix) {
        if (*prefix++ != *str++) return 0;
    }
    return 1;
}

<*
 @require msg != null
 @param [&in] msg
*>
fn void print_error(char *msg)
{
    if (msg) {
        (void)_write(2, msg, strlen_custom(msg));
    }
}

<*
 @require path != null
 @param [&in] path
*>
fn char *get_real_path(char *path, char *real_path)
{
    char* rp1, rp2;
    char* p1, p2;
    // TODO: Use "freestanding"
    char[PATH_MAX] buf @noinit;

    if (path == null) {
        return null;
    } else {
        p1 = p2 = path;
    }

    if (real_path == null) {
        rp1 = rp2 = &buf;
    } else {
        rp1 = rp2 = real_path;
    }

    if (*p1 == '/') {
        p1++;
        p2++;
        rp2[0] = '/';
        rp2[1] = 0;
    } else {
        if (_getcwd(rp2, PATH_MAX) <= 0) {
            return null;
        }
        rp2 += strlen_custom(rp2);
    }

    while (*p2) {
        p2 = strchr_custom(p1, '/');
        if (!p2) {
            p2 = strchr_custom(p1, 0);
        }
        switch (p2 - p1) {
        case 0:
            break;
        case 1:
            if (p1[0] == '.') {
                break;
            }
        case 2:
            if (p1[0] == '.' && p1[1] == '.') {
                rp2 = strrchr_custom(rp1, '/');
                if (rp2 != rp1) {
                    rp2[0] = 0;
                } else {
                    rp2[1] = 0;
                }
                break;
            }
        default:
            *rp2 = '/';
            rp2++;
            memcpy_custom(rp2, p1, p2 - p1);
            rp2 += p2 - p1;
            break;
        }
        p1 = p2 + 1;
    };

    if (rp2 == rp1) {
        rp2++;
    }
    *rp2 = 0;

    if (real_path == null) {
        real_path = _mmap(rp2 - rp1 + 1);
        if (real_path == null) {
            return null;
        }
        memcpy_custom(real_path, &buf, rp2 - rp1 + 1);
    }

    return real_path;
}

module readline_fzf_hook_start;

fn void readline_fzf_hook_start_c3(usz *sp) @export("readline_fzf_hook_start_c3")
{
    int argc = (int)*sp;
    char **argv = (char **)(sp + 1);
    char **envp = &argv[argc + 1];
    char **e;
    long env_count;
    char *path_env;
    char *libso;
    usz prefix_len;
    usz libso_len;
    usz prefix_libso_len;
    char *prefix_libso_env;
    char *target_prog = argv[1];
    char **target_argv = argv + 1;
    char **new_envp;
    usz target_prog_len;
    char *p_start;
    char *p_end;
    long dir_len;
    char *target_path_prog;

    if (argc < 2) {
        print_error("Usage: ");
        print_error(argv[0]);
        print_error(" <program> [args...]\n");
        __exit(1);
    }

    for (e = envp, env_count = 0, path_env = null; *e; e++) {
        env_count++;
        if (str_starts_with(*e, "PATH=")) {
            path_env = *e + 5;
        }
    }

    if (*argv[0] != '/') {
        libso = get_real_path(argv[0], null);
        if (!libso) {
            print_error("Error: Failed to get real path.\n");
            __exit(1);
        }
    } else {
        libso = argv[0];
    }

    prefix_len = LD_PRELOAD_PREFIX.len;
    libso_len = strlen_custom(libso);
    prefix_libso_len = prefix_len + libso_len;

    prefix_libso_env = _mmap(prefix_libso_len + 1);
    if (prefix_libso_env == MAP_FAILED) {
        print_error("Error: Failed to allocate memory.\n");
        __exit(127);
    }

    memcpy_custom(prefix_libso_env, &LD_PRELOAD_PREFIX, prefix_len);
    memcpy_custom(prefix_libso_env + prefix_len, libso, libso_len);
    prefix_libso_env[prefix_libso_len] = '\0';

    new_envp = _mmap((env_count + 2) * char*.sizeof);
     if (new_envp == MAP_FAILED) {
        print_error("Error: Failed to allocate memory.\n");
        __exit(127);
    }

    memcpy_custom(new_envp, envp, env_count * char*.sizeof);
    new_envp[env_count] = prefix_libso_env;
    new_envp[env_count + 1] = null;

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
        if (dir_len < 0) {
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

fn void _start() @naked @export("readline_fzf_hook_start")
{
    asm {
        xorq $rbp, $rbp;
        movq $rdi, $rsp;
        // TODO: Use "lea" or "call"
        pushq ((usz)&readline_fzf_hook_start_c3);
        ret;
    }
}
