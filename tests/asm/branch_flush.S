    .option norvc
    .option norelax

    .section .text.init
    .globl _start

_start:
    addi x1, x0, 1
    beq  x1, x1, branch_target

    addi x2, x0, 2
    addi x3, x0, 99

branch_target:
    addi x3, x0, 3
    addi x4, x0, 4

    nop
    nop
