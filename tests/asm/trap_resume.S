    .option norvc
    .section .text
    .globl _start

_start:
    la   x1, trap_handler
    csrw mtvec, x1
    addi x10, x0, 0
faulting_ecall:
    ecall
    addi x10, x10, 1
    jal  x0, done

trap_handler:
    csrr x2, mcause
    csrr x3, mepc
    csrr x4, mtval
    addi x3, x3, 4
    csrw mepc, x3
    mret

done:
    addi x11, x0, 11
    nop
    nop
