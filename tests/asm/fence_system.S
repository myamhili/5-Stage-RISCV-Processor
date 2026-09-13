    .option norvc
    .section .text
    .globl _start

_start:
    addi x1, x0, 1
    fence rw, rw
    fence.i
    addi x2, x1, 2
    nop
    nop
