# readline-fzf-hook.c3
Enhanced Readline with fzf-powered hooks

## Features
- Tab Completion(`Tab`)
- Search history(`C-r`)

## Requirements
- [c3c](https://github.com/c3lang/c3c)(v0.7.2)
- make
- fzf

## Build
```sh
make all
```

## Usage
```sh
LD_PRELOAD=/your/path/readline_fzf_hook.so your_program
```

## Limitations
- Dynamically linked libreadline

## License
MIT
