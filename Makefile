CC := $(shell command -v gcc || command -v clang 2>/dev/null)
C3C := $(shell command -v c3c 2>/dev/null)
CFLAGS = -std=c99 -Wall -g -O2 -ffunction-sections -fdata-sections -fPIC
C3_LDFLAGS =

ARCH := $(shell uname -m)

OUTDIR = build
OUTLIB = readline_fzf_hook
C3_SRCS = readline_fzf_hook.c3
EXTRA_C_SRCS =
EXTRA_C3_SRCS =
EXTRA_OBJS =

C3_BUILD_OPTS = --output-dir $(OUTDIR) --build-dir $(OUTDIR) --obj-out $(OUTDIR)

ifneq ($(CC),)
	CFLAGS += -I./c/arch/$(ARCH) -fno-stack-protector -ffreestanding
	EXTRA_C_SRCS += c/export_symbol.c
	EXTRA_OBJS += $(addprefix $(OUTDIR)/,$(patsubst %.c,%.o,$(EXTRA_C_SRCS)))
	EXTRA_C3_SRCS += readline_fzf_hook_start.c3
	EXTRA_OBJS += $(addprefix $(OUTDIR)/,$(patsubst %.c3,%.o,$(EXTRA_C3_SRCS)))
	C3_LDFLAGS += $(addprefix -z ,$(EXTRA_OBJS))
	C3_LDFLAGS += $(addprefix -z ,$(EXTRA_C3_OBJS))
	C3_LDFLAGS += -z -e -z readline_fzf_hook_start
endif

.PHONY: all clean

all: $(OUTLIB)

$(OUTLIB): $(EXTRA_OBJS)
	$(C3C) dynamic-lib \
		$(C3_BUILD_OPTS) \
		$(C3_LDFLAGS) \
		-o $@ $(C3_SRCS)

$(OUTDIR)/%.o: %.c
	mkdir -p $(dir $@)
	$(CC) $(CFLAGS) -c -o $@ $<

$(OUTDIR)/%.o: %.c3
	mkdir -p $(dir $@)
	$(C3C) compile-only \
		--use-stdlib=no \
		--safe=no \
		--no-headers \
		--obj-out $(OUTDIR) \
		--build-dir $(OUTDIR) \
		--single-module=yes \
		-o $@ \
		$<

clean:
	rm -rf $(OUTDIR)
