all:
	c3c dynamic-lib ./readline_fzf_hook.c3

clean:
	rm -rf .build readline_fzf_hook.so
