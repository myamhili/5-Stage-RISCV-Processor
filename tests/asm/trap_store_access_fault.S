.option norvc
.option norelax
.section .text
.global _start
_start:
lui x1, 0x90000
sw x1, 0(x1)
jal x0, wrong
wrong:
addi x30, x0, 1
j .
