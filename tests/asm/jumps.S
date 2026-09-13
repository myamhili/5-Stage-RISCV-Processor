    .option norvc
    .option norelax

    .section .text.init
    .globl _start

_start:
    jal  x5, after_jal

    addi x2, x0, 99
    addi x3, x0, 99

after_jal:
    addi x4, x5, 1
    // JALR must clear target bit zero, so 33 redirects to address 32.
    addi x1, x0, 33
    jalr x6, 0(x1)

    addi x7, x0, 99
    addi x8, x0, 99

after_jalr:
    addi x9, x6, 1
    nop
    nop
