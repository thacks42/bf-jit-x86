# bf-x86-jit

## Quick Start

run `make` to assemble, then run `./bf.run my_program.b` to run a brainfuck program.

Input is fetched from stdin, so if your program wants non-newline-but-EOF-terminated input, use

`echo -n "123" | ./bf.run my_program.b`

EOF is forwarded as `0` and not as `-1`, but this can be trivially changed by modifying the `read` section in `bf.asm`

