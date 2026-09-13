    .option norvc
    .section .text
    .globl _start

_start:
    la      x1, handler
    csrw    mtvec, x1

    // Only timer is locally enabled while the testbench holds external high.
    addi    x2, x0, 0x80
    csrw    mie, x2
    addi    x3, x0, 8
    csrw    mstatus, x3
    addi    x12, x0, 1

    // Enabling MEIE must take the already-pending external interrupt after
    // this CSR retires, without allowing resume to retire first.
    lui     x2, 0x1
    addi    x2, x2, -0x800
    csrw    mie, x2
resume:
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

