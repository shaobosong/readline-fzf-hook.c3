CC := $(shell command -v gcc || command -v clang 2>/dev/null)

ARCH := $(shell uname -m)

all:
ifeq ($(ARCH),x86_64)
ifneq ($(CC),)
	@echo "Building for x86_64 architecture with $(CC)"
	$(CC) -c -o arch/x86_64/entry.o arch/x86_64/entry.S
	c3c dynamic-lib -z arch/x86_64/entry.o -z -e -z _readline_fzf_hook_start ./readline_fzf_hook.c3
else # CC
	@echo "No suitable compiler (gcc or clang) found for x86_64 build"
	c3c dynamic-lib ./readline_fzf_hook.c3
endif # CC
else # ARCH
	@echo "Building for non-x86_64 architecture"
	c3c dynamic-lib ./readline_fzf_hook.c3
endif # ARCH

clean:
	rm -rf .build readline_fzf_hook.so arch/x86_64/entry.o
