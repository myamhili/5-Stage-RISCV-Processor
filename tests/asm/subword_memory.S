    .option norvc
    .option norelax

    .section .text.init
    .globl _start

_start:
    # Build 0x80FF7F01 and verify signed/unsigned byte and halfword loads.
    lui  x1, 0x80ff8
    addi x1, x1, -255
    sw   x1, 32(x0)
    lb   x2, 32(x0)
    lb   x3, 33(x0)
    lb   x4, 34(x0)
    lbu  x5, 34(x0)
    lb   x6, 35(x0)
    lbu  x7, 35(x0)
    lh   x8, 32(x0)
    lh   x9, 34(x0)
    lhu  x10, 34(x0)

    # Exercise all four byte lanes.
    addi x11, x0, 0x11
    sb   x11, 40(x0)
    addi x11, x0, 0x22
    sb   x11, 41(x0)
    addi x11, x0, 0x33
    sb   x11, 42(x0)
    addi x11, x0, 0x44
    sb   x11, 43(x0)
    lw   x12, 40(x0)

    # Exercise both aligned halfword lanes.
    lui  x13, 0xa
    addi x13, x13, 0x1b2
    sh   x13, 44(x0)
    lui  x14, 0xc
    addi x14, x14, 0x3d4
    sh   x14, 46(x0)
    lw   x15, 44(x0)

    # Verify that partial stores preserve untouched bytes.
    lui  x16, 0x55667
    addi x16, x16, 0x788
    sw   x16, 48(x0)
    addi x17, x0, 0xaa
    sb   x17, 49(x0)
    lw   x18, 48(x0)
    addi x19, x0, -2
    sh   x19, 50(x0)
    lw   x20, 48(x0)

    # Byte load-use hazard: this must insert exactly one stall.
    lb   x21, 35(x0)
    addi x22, x21, 1

    # Forward an ALU result into byte-store data, then load it back.
    addi x23, x0, 0x5a
    sb   x23, 52(x0)
    lbu  x24, 52(x0)

    # Apply the same byte strobes to the aligned GPIO MMIO register.
    lui  x25, 0x40001
    addi x26, x0, 0x12
    sb   x26, 1(x25)
    addi x26, x0, 0x34
    sh   x26, 2(x25)

    nop
    nop
    nop
