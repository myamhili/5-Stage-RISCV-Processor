    .option norvc
    .section .text
    .globl _start

_start:
    addi x1, x0, 1
    csrw misa, x1
    addi x2, x0, 2

