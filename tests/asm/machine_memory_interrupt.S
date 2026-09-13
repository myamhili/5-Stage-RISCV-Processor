    .option norvc
    .section .text
    .globl _start

_start:
    la      x1, handler
    csrw    mtvec, x1
    addi    x2, x0, 0x80
    csrw    mie, x2
    addi    x3, x0, 8
    csrw    mstatus, x3

    lui     x5, 0x10000
    addi    x6, x0, 0x55
store_instruction:
    sw      x6, 0(x5)
load_instruction:
    lw      x7, 0(x5)
after_load:
    addi    x8, x7, 1
    addi    x9, x0, 0x5a
done:
    jal     x0, done

    .org 0x80
handler:
    csrr    x20, mcause
    csrr    x21, mepc
    csrr    x22, mtval
    addi    x23, x23, 1
    mret

