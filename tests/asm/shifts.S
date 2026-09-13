    .option norvc
    .option norelax

    .section .text.init
    .globl _start

_start:
    addi x1,  x0, 1
    slli x2,  x1, 31
    srli x3,  x2, 31

    addi x4,  x0, -16
    srai x5,  x4, 2
    srli x6,  x4, 2

    addi x7,  x0, 33
    sll  x8,  x1, x7
    srl  x9,  x2, x7
    sra  x10, x4, x7

    slli x11, x1, 0
    srai x12, x2, 31
    srli x13, x2, 31
    sll  x14, x3, x7

    nop
    nop
