.option norvc
.option norelax
.section .text
.global _start
_start:
lui x1, 0x10000
lui x2, 0x02a00
addi x2, x2, 0x513
sw x2, 0(x1)
lui x3, 0x28
addi x3, x3, 0x67
sw x3, 4(x1)
fence.i
jalr x5, 0(x1)
addi x11, x10, 0
lui x2, 0x02b00
addi x2, x2, 0x513
sw x2, 0(x1)
fence.i
jalr x5, 0(x1)
addi x31, x0, 1
j .
