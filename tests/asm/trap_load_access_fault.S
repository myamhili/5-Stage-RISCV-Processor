.option norvc
.option norelax
.section .text
.global _start
_start:
lui x1, 0x90000
lb x0, 3(x1)
lui x2, 0x40001
sw x1, 0(x2)
j .
