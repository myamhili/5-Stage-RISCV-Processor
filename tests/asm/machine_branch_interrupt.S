    .option norvc
    .section .text
    .globl _start

_start:
    la      x1, handler
    csrw    mtvec, x1
    lui     x2, 0x1
    addi    x2, x2, -0x800
    csrw    mie, x2
    addi    x3, x0, 8
    csrw    mstatus, x3
    addi    x10, x0, 1
branch_instruction:
    beq     x10, x10, branch_target
    addi    x11, x0, 0x7f
branch_target:
    addi    x12, x0, 0x5a
done:
    jal     x0, done

    .org 0x80
handler:
    csrr    x20, mcause
    csrr    x21, mepc
    csrr    x22, mtval
    addi    x23, x23, 1
    mret

