    .option norvc
    .option norelax

    .section .text.init
    .globl _start

_start:
    addi  x1,  x0, -1
    addi  x2,  x0, 1

    slt   x3,  x1, x2
    sltu  x4,  x1, x2
    slt   x5,  x2, x1
    sltu  x6,  x2, x1

    slti  x7,  x1, 0
    slti  x8,  x2, -1
    sltiu x9,  x0, -1
    sltiu x10, x1, 1

    addi  x11, x0, -2048
    slti  x12, x11, -2047
    sltu  x13, x0, x0
    slt   x14, x1, x1

    slt   x15, x1, x2
    add   x16, x15, x2

    nop
    nop
