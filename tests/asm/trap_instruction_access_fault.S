.option norvc
.option norelax
.section .text
.global _start
_start:
lui x1, 0x90000
jalr x5, 0(x1)
addi x30, x0, 1
j .
