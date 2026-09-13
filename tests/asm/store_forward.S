    .option norvc
    .option norelax

    .section .text.init
    .globl _start

_start:
    addi x1, x0, 7
    addi x2, x0, 5
    add  x3, x1, x2
    sw   x3, 24(x0)
    lw   x5, 24(x0)

    nop
    nop
    nop
