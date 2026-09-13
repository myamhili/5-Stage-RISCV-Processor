    .option norvc
    .section .text
    .globl _start

_start:
    la      x1, handler
    csrw    mtvec, x1

    // Unsupported mie bits must be masked off. The testbench holds one or
    // more interrupt inputs high and checks the corresponding mip value.
    addi    x2, x0, -1
    csrw    mie, x2
    csrr    x4, mie
    csrr    x5, mip

    // The pending interrupt must be taken immediately after this instruction
    // retires; no instruction at resume may retire first.
    addi    x3, x0, 8
    csrw    mstatus, x3

resume:
    addi    x10, x10, 1
    addi    x11, x0, 0x5a
done:
    jal     x0, done

    .org 0x80
handler:
    csrr    x20, mcause
    csrr    x21, mepc
    csrr    x22, mtval
    addi    x23, x23, 1
    mret

