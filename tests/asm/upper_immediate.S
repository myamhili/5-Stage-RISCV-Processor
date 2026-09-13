    .option norvc
    .option norelax

    .section .text.init
    .globl _start

_start:
    lui   x1, 0x12345
    addi  x5, x1, 1
    auipc x2, 0
    auipc x3, 1
    add   x4, x2, x3

    nop
    nop
