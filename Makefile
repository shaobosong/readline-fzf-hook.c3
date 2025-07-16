CC := $(shell command -v gcc || command -v clang 2>/dev/null)
CFLAGS = -std=c99 -Wall -g -O0 -ffunction-sections -fdata-sections -fPIC
C3_LDFLAGS =

ARCH := $(shell uname -m)

OUTDIR = build
OUTLIB = readline_fzf_hook
C3_SRCS = readline_fzf_hook.c3
EXTRA_SRCS =
EXTRA_OBJS =

ifeq ($(ARCH),x86_64)
ifneq ($(CC),)
	CFLAGS += -I./c/arch/x86_64 -fno-stack-protector -ffreestanding
	EXTRA_SRCS += c/readline_fzf_hook_start.c
	EXTRA_OBJS = $(addprefix $(OUTDIR)/,$(patsubst %.c,%.o,$(EXTRA_SRCS)))
	C3_LDFLAGS += $(addprefix -z ,$(EXTRA_OBJS))
	C3_LDFLAGS += -z -e -z readline_fzf_hook_start
endif
endif

.PHONY: all clean

all: $(OUTLIB)

$(OUTLIB): $(EXTRA_OBJS)
	c3c dynamic-lib \
		--output-dir $(OUTDIR) \
		--build-dir $(OUTDIR) \
		--obj-out $(OUTDIR) \
		$(C3_LDFLAGS) \
		-o $@ $(C3_SRCS)

$(OUTDIR)/%.o: %.c
	mkdir -p $(dir $@)
	$(CC) $(CFLAGS) -c -o $@ $<

clean:
	rm -rf $(OUTDIR)
