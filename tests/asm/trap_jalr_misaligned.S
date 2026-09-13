    .option norvc
    .section .text
    .globl _start

_start:
    addi x1, x0, 2
    jalr x0, 0(x1)
    addi x2, x0, 2

