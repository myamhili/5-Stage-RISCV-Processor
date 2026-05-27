# Simple RISC-V Processor

A basic 5-stage pipelined RISC-V processor implementation in Verilog, supporting a subset of the RV32I base integer instruction set. The pipeline includes data forwarding and hazard detection units.

## Overview

This processor implements a subset of RISC-V RV32I instructions in a 5-stage pipeline (IF, ID, EX, MEM, WB):
- **Arithmetic/Logic**: add, sub, and, or, xor
- **Memory Access**: lw (load word), sw (store word)
- **Control Flow**: beq (branch if equal)

## Project Structure

```
Simple-RISC-Processor/
├── rtl/                    # RTL design files
│   ├── pc.v               # Program Counter
│   ├── instruction_memory.v  # Instruction ROM
│   ├── control_unit.v     # Instruction Decoder & Control
│   ├── register_file.v    # 32 General-purpose Registers
│   ├── alu.v              # Arithmetic Logic Unit
│   ├── data_memory.v      # Data RAM
│   └── risc_processor.v   # Top-level processor
├── sim/                   # Simulation files
│   └── tb_risc_processor.v  # Testbench
└── README.md              # This file
```

## Modules

| Module | Description |
|--------|-------------|
| **PC** | Program Counter - holds address of current instruction |
| **Instruction Memory** | ROM storing the program (64 words) |
| **Control Unit** | Decodes 32-bit instructions and generates control signals |
| **Register File** | 32 registers (x0-x31), x0 is hardwired to 0 |
| **ALU** | Performs arithmetic and logical operations |
| **Data Memory** | RAM for lw/sw instructions (64 words) |

## Instruction Encoding

The processor supports RISC-V RV32I format:
- **R-type**: add, sub, and, or, xor (opcode: 0110011)
- **I-type**: lw (opcode: 0000011)
- **S-type**: sw (opcode: 0100011)
- **B-type**: beq (opcode: 1100011)

## Simulation

To run the testbench with Icarus Verilog:

```bash
# Compile
iverilog -o sim/risc_processor.vvp rtl/*.v sim/tb_risc_processor.v

# Run
vvp sim/risc_processor.vvp
```

## Sample Program

The instruction memory is preloaded with a sample program:
```
Address 0:  add x3, x1, x2
Address 4:  sub x4, x3, x2
Address 8:  and x5, x3, x4
Address C:  or  x6, x4, x5
Address 10: lw  x7, 0(x1)
Address 14: sw  x7, 4(x1)
Address 18: beq x3, x4, 8
```

## License

MIT License