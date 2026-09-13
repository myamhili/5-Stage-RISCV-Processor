    .option norvc
    .section .text
    .globl _start

_start:
    ecall
    addi x1, x0, 1

