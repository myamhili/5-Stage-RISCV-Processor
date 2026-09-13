    .option norvc
    .section .text
    .globl _start

_start:
    # jal x0, +2. The target is 2-byte aligned but invalid for RV32I IALIGN=32.
    .word 0x0020006f
    addi x1, x0, 1

