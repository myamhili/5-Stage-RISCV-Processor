    .option norvc
    .option norelax

    .section .text.init
    .globl _start

_start:
    addi x1, x0, 10
    addi x2, x0, 5
    add  x3, x1, x2
    add  x4, x3, x2
    add  x5, x4, x3

    nop
    nop
