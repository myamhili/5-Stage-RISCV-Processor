# Simple RISC-V Processor

A basic 5-stage pipelined RISC-V processor implementation in Verilog, supporting a subset of the RV32I base integer instruction set. The pipeline includes data forwarding and hazard detection units.

## Overview

This processor implements a subset of RISC-V RV32I instructions in a 5-stage pipeline (IF, ID, EX, MEM, WB):
- **Arithmetic/Logic**: `add`, `sub`, `and`, `or`, `xor`
- **Immediate Arithmetic**: `addi`
- **Memory Access**: `lw` (load word), `sw` (store word)
- **Control Flow**: `beq` (branch if equal)

## Project Status & Hardware Stats

This project has been fully verified in simulation and successfully synthesized for the **Basys 3 (Artix-7 xc7a35tcpg236-1)** FPGA board. 

**Simulation Verification:**
The included testbench executes a machine-code program to calculate the **Fibonacci sequence**, successfully outputting the sequence (`13, 21, 34, 55...`) to the simulated LED outputs over a 1000ns run.

**Synthesis Results (Vivado 2025.2):**
- **LUTs (Look-Up Tables):** ~1,504 (7.23% utilization)
- **Registers (Flip-Flops):** ~3,426 (8.24% utilization)
- **Max Clock Speed:** ~99.2 MHz (Constrained at 100 MHz with -0.080ns WNS slack)

## Project Structure

```text
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
├── basys3.xdc             # Constraints for the Basys 3 FPGA
├── build.tcl              # Vivado Tcl script for Synthesis
├── build_bitstream.tcl    # Vivado Tcl script for full Bitstream Generation
├── sim.tcl                # Vivado Tcl script for Simulation
└── README.md              # This file
```

## Running the Design (Vivado)

### 1. Simulation
To run the behavioral simulation and verify the Fibonacci calculation:
```bash
vivado -mode batch -source sim.tcl
```
*(You can also open the generated project in the Vivado GUI to view the waveforms).*

### 2. Synthesis & Implementation
To generate hardware utilization and timing reports without needing a physical board:
```bash
vivado -mode batch -source build.tcl
```

### 3. Bitstream Generation
To compile the final `.bit` file to flash to a Basys 3 FPGA board:
```bash
vivado -mode batch -source build_bitstream.tcl
```

## License

MIT License
