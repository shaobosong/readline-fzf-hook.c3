# readline-fzf-hook.c3
Enhanced Readline with fzf-powered hooks

## Features
- Tab Completion(`Tab`)
- Search history(`C-r`)

## Requirements
- [c3c](https://github.com/c3lang/c3c)(v0.7.2)
- make
- fzf
- `gcc` or `clang` (optional)

## Build
```sh
make
```

## Usage
```sh
LD_PRELOAD=/your/path/readline_fzf_hook.so your_program
```
or (only support in `x86_64`)
```sh
/your/path/readline_fzf_hook.so your_program
```

## Limitations
- Dynamically linked libreadline

## License
MIT
