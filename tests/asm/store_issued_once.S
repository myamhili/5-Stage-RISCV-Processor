.option norvc
.option norelax
.section .text
.global _start
_start:
lui x1, 0x40001
addi x5, x0, 90
sb x5, 1(x1)
lhu x6, 0(x1)
addi x31, x0, 1
j .
