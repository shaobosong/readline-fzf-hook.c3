#define hidden __attribute__((__visibility__("hidden")))

#include "reloc_arch.h"

void (*readline_fzf_hook_start_c3_sym)(unsigned long *sp);
hidden void __export_symbol()
{
    GETFUNCSYM(&readline_fzf_hook_start_c3_sym, readline_fzf_hook_start_c3);
}
