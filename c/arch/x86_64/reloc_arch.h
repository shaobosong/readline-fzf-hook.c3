#define GETFUNCSYM(fp, sym) __asm__ ( \
        ".hidden " #sym "\n" \
        "    lea " #sym "(%%rip),%0\n" \
        : "=r"(*fp) : : "memory" )
