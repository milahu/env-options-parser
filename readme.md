# env-options-parser

simple and wrong argument parser for /usr/bin/env = gnu coreutils env

it is wrong because i use `xargs` to tokenize the input string
but this way, extra whitespace is lost

a correct implementation would mirror the exact behavior of [coreutils/src/env.c][1]

[1]: https://github.com/coreutils/coreutils/blob/master/src/env.c
