    .option norvc
    .option norelax

    .section .text.init
    .globl _start

_start:
    addi x1, x0, -1
    addi x2, x0, 1
    addi x3, x0, 0

    beq  x2, x2, beq_taken
    addi x10, x0, 99
beq_taken:
    addi x3, x3, 1
    beq  x1, x2, fail

    bne  x1, x2, bne_taken
    addi x11, x0, 99
bne_taken:
    addi x3, x3, 2
    bne  x2, x2, fail

    blt  x1, x2, blt_taken
    addi x12, x0, 99
blt_taken:
    addi x3, x3, 4
    blt  x2, x1, fail

    bge  x2, x1, bge_taken
    addi x13, x0, 99
bge_taken:
    addi x3, x3, 8
    bge  x1, x2, fail

    bltu x2, x1, bltu_taken
    addi x14, x0, 99
bltu_taken:
    addi x3, x3, 16
    bltu x1, x2, fail

    bgeu x1, x2, bgeu_taken
    addi x15, x0, 99
bgeu_taken:
    addi x3, x3, 32
    bgeu x2, x1, fail

    addi x5, x0, 170
    lw   x4, 0(x0)
    beq  x4, x5, load_branch_taken
    addi x16, x0, 99
load_branch_taken:
    addi x3, x3, 64

    addi x6, x0, 7
    addi x8, x0, 7
    beq  x8, x6, forward_branch_taken
    addi x17, x0, 99
forward_branch_taken:
    addi x3, x3, 128
    jal  x0, done

fail:
    addi x31, x0, 99

done:
    nop
    nop
