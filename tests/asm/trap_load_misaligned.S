    .option norvc
    .section .text
    .globl _start

_start:
    addi x1, x0, 1
    addi x2, x0, 0x55
    lh   x2, 0(x1)
    addi x3, x0, 3

