    .option norvc
    .option norelax

    .section .text.init
    .globl _start

_start:
    addi x1, x0, 42
    sw   x1, 16(x0)
    lw   x3, 16(x0)
    addi x4, x3, 57
    sw   x4, 20(x0)

    nop
    nop
