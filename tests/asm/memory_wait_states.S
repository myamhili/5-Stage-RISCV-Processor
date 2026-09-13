.option norvc
.option norelax
.section .text
.global _start
_start:
lui x1, 0x10000
addi x5, x0, 7
sw x5, 0(x1)
lw x6, 0(x1)
add x7, x5, x6
sw x7, 4(x1)
lb x8, 4(x1)
csrw mscratch, x8
csrr x9, mscratch
beq x9, x7, good
addi x30, x0, 1
good:
addi x31, x0, 1
j .
