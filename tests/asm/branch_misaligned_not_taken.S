    .option norvc
    .section .text
    .globl _start

_start:
    addi x1, x0, 1
    # beq x0, x1, +2. The target is misaligned, but the branch is not taken.
    .word 0x00100163
    addi x2, x0, 2
    nop
    nop

