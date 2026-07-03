# 5-Stage RISC-V Subset Processor

A 5-stage pipelined 32-bit RISC-V subset processor written in Verilog and targeted at the Basys 3 Artix-7 FPGA. The core implements instruction fetch, decode, execute, memory, and writeback stages with forwarding, load-use hazard detection, branch flushing, and MMIO LED output.

## Supported Instructions

This is an RV32I subset implementation, not a complete RV32I core.

- **Arithmetic/logic:** `add`, `sub`, `and`, `or`, `xor`
- **Immediate arithmetic/logic:** `addi`, `andi`, `ori`, `xori`
- **Memory:** `lw`, `sw`
- **Control flow:** `beq`

## Verification

The simulation flow uses a self-checking Verilog testbench and directed machine-code programs loaded into instruction memory with `$readmemh`. Each test checks final architectural state through register, memory, or MMIO LED scoreboards and exits with a failed simulator status on mismatch.

Current directed tests:

| Test | Coverage |
| --- | --- |
| `alu.hex` | R-type ops, immediate ops, and `x0` immutability |
| `memory.hex` | `sw`, `lw`, memory addressing, dependent load result |
| `forwarding.hex` | back-to-back EX/MEM and MEM/WB ALU forwarding |
| `load_use.hex` | load-use hazard stall followed by dependent ALU ops |
| `branch_flush.hex` | taken branch flushing wrong-path instructions |
| `store_forward.hex` | forwarding ALU result into store data and reloading it |

Run the regression with Icarus Verilog:

```powershell
powershell -ExecutionPolicy Bypass -File sim\run_tests.ps1
```

You should see each directed test print `TEST <name> PASS`, followed by:

```text
All self-checking simulation tests passed.
```

The instruction memory still includes the original Fibonacci/MMIO LED program as its default image when no `+PROGRAM=...` plusarg is provided.

## Timing And FPGA Flow

Vivado build scripts target the Basys 3 Artix-7 `xc7a35tcpg236-1`.

Latest post-implementation result from Vivado 2025.2:

| Metric | Result |
| --- | --- |
| Clock constraint | 10.000 ns / 100 MHz |
| Worst negative slack | +0.217 ns |
| Total negative slack | 0.000 ns |
| Timing status | All user-specified timing constraints met |
| Slice LUTs | 1,509 / 20,800 (7.25%) |
| Slice registers | 3,428 / 41,600 (8.24%) |

The current worst setup path is route-dominated forwarding/control logic from the EX/MEM destination register compare path into the ID/EX register enable path:

- Source: `ex_mem_rd_reg[1]/C`
- Destination: `id_ex_reg_read_data1_reg[0]/CE`
- Data path delay: 9.530 ns
- Logic/route split: 2.515 ns logic, 7.015 ns route
- Logic levels: 10

The implementation flow runs synthesis, place, and route before generating timing and utilization reports:

```powershell
vivado -mode batch -source build.tcl
```

Reports are generated under `vivado_proj/`:

- `timing_summary.txt`
- `utilization_summary.txt`

The timing-closure cleanup focused on pipeline flush control:

- branch/load-use flushes are handled synchronously instead of being mixed into asynchronous reset logic
- branch flush selection was moved off the IF/ID clock-enable path
- ID/EX bubble insertion clears only side-effecting control bits instead of muxing branch flush across all datapath registers

These changes removed recovery/removal timing issues on computed flush signals and closed the 100 MHz post-implementation constraint.

To generate a bitstream for the Basys 3 top-level wrapper:

```powershell
vivado -mode batch -source build_bitstream.tcl
```

## Project Structure

```text
Simple-RISC-Processor/
|-- rtl/
|   |-- pc.v
|   |-- instruction_memory.v
|   |-- control_unit.v
|   |-- register_file.v
|   |-- alu.v
|   |-- data_memory.v
|   |-- risc_processor.v
|   `-- top_basys3.v
|-- sim/
|   |-- tb_risc_processor.v
|   `-- run_tests.ps1
|-- tests/
|   |-- alu.hex
|   |-- memory.hex
|   |-- forwarding.hex
|   |-- load_use.hex
|   |-- branch_flush.hex
|   `-- store_forward.hex
|-- basys3.xdc
|-- constraints.xdc
|-- build.tcl
|-- build_bitstream.tcl
|-- sim.tcl
`-- README.md
```

## License

MIT License
