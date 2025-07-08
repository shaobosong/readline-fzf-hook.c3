all:
	c3c dynamic-lib ./liberl.c3

clean:
	rm -rf .build liberl.so
