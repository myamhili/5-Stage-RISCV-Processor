    .option norvc
    .section .text
    .globl _start

_start:
    csrr  x1, misa
    csrrsi x2, misa, 0
    nop
    nop

