.option norvc
.option norelax
.section .text
.global _start
_start:
addi x1, x0, 85
sw x1, 0(x0)
addi x30, x0, 1
j .
