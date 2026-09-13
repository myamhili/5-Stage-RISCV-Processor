    .option norvc
    .option norelax

    .section .text.init
    .globl _start

_start:
    addi x1, x0, 0
    jal  x0, check_counter

backward_target:
    addi x1, x1, 1

check_counter:
    beq  x1, x0, do_backward
    jal  x0, done

do_backward:
    jal  x5, backward_target
    addi x2, x0, 99

done:
    addi x3, x5, 1
    nop
    nop
