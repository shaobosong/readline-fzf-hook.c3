.section .data
    ld_path:
        .ascii "/lib64/ld-linux-x86-64.so.2\0"
    ld_preload:
        .ascii "--preload\0"

.section .text
    .global _readline_fzf_hook_start

_readline_fzf_hook_start:
    pop %rdi

    lea ld_preload(%rip), %rsi
    push %rsi
    lea ld_path(%rip), %rsi
    push %rsi

    add $2, %rdi

    cmp $4, %rdi
    jl exit_error

    mov %rsp, %rsi

    lea (%rsp, %rdi, 8), %rdx
    add $8, %rdx

    mov %rsi, %r12
    mov %rdx, %r13

    mov (%r12), %rdi
    lea (%r12), %rsi
    mov %r13, %rdx

    mov $59, %rax
    syscall

exit_error:
    mov $1, %rdi

    mov $231, %rax
    syscall
