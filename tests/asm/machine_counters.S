    .option norvc
    .section .text
    .globl _start

_start:
    csrr    x1, mcycle
    addi    x2, x0, 1
    addi    x2, x2, 1
    csrr    x3, mcycle
    sltu    x4, x1, x3

    csrr    x5, minstret
    addi    x6, x0, 1
    addi    x6, x6, 1
    csrr    x7, minstret
    sltu    x8, x5, x7

    csrr    x9, mcycleh
    csrr    x10, minstreth
    addi    x11, x0, 0x5a
done:
    jal     x0, done

