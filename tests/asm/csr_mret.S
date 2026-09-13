    .option norvc
    .section .text
    .globl _start

_start:
    addi   x1, x0, 0x55
    csrrw  x2, mscratch, x1
    csrrs  x3, mscratch, x0
    addi   x4, x0, 0x0f
    csrrs  x5, mscratch, x4
    addi   x6, x0, 3
    csrrc  x7, mscratch, x6
    csrrwi x8, mscratch, 7
    csrrsi x9, mscratch, 8
    csrrci x10, mscratch, 1
    csrrs  x11, mscratch, x0

    la     x12, resume
    csrw   mepc, x12
    mret
    addi   x13, x0, 99
    addi   x14, x0, 99

resume:
    addi   x13, x0, 13
    addi   x14, x0, 14
    nop
    nop

