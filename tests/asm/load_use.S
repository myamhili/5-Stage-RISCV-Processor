    .option norvc
    .option norelax

    .section .text.init
    .globl _start

_start:
    lw   x2, 0(x0)
    addi x3, x2, 5
    add  x4, x3, x0

    nop
    nop
    nop
