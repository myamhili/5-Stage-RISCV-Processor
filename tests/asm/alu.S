    .option norvc
    .option norelax

    .section .text.init
    .globl _start

_start:
    addi x1, x0, 5
    addi x2, x0, 3

    add  x3, x1, x2
    sub  x4, x1, x2
    and  x5, x1, x2
    or   x6, x1, x2
    xor  x7, x1, x2

    addi x0, x0, 7

    nop
    nop