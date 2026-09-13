# 5-Stage RV32I RISC-V Processor

A 5-stage pipelined 32-bit RISC-V processor written in Verilog. The core
implements RV32I with `Zicsr` and `Zifencei`, precise Machine-mode exceptions
and interrupts, 64-bit Machine counters, forwarding, load-use and CSR hazard
handling, control-flow flushing, and MMIO LED output. The current FPGA scripts
use the Basys 3 Artix-7 as a representative Xilinx target.

The target architecture and portability rules for expanding the subset into a
complete `RV32IM_Zicsr_Zifencei` bare-metal processor are defined in
[`docs/architecture.md`](docs/architecture.md). The target keeps synthesizable
RTL in Verilog and separates the portable CPU/SoC from Xilinx board wrappers.

<img width="1174" height="646" alt="unnamed" src="https://github.com/user-attachments/assets/9cd86f4a-4fbe-4710-94a0-9286ee87db11" />
<img width="1900" height="394" alt="timing reports" src="https://github.com/user-attachments/assets/3411a6e4-917c-4cfc-828f-f3a2c123e55b" />
<img width="2316" height="1332" alt="waveform" src="https://github.com/user-attachments/assets/806eb8ef-fcc7-4928-977a-4df385d4549c" />




## Supported Instructions

The implemented instruction set is RV32I plus `Zicsr` and `Zifencei`.

- **Arithmetic/logic:** `add`, `sub`, `and`, `or`, `xor`, `slt`, `sltu`, `sll`, `srl`, `sra`
- **Immediate arithmetic/logic:** `addi`, `andi`, `ori`, `xori`, `slti`, `sltiu`, `slli`, `srli`, `srai`
- **Upper immediate:** `lui`, `auipc`
- **Memory:** `lb`, `lbu`, `lh`, `lhu`, `lw`, `sb`, `sh`, `sw`
- **Control flow:** `beq`, `bne`, `blt`, `bge`, `bltu`, `bgeu`, `jal`, `jalr`
- **Ordering and system:** `fence`, `fence.i`, `ecall`, `ebreak`, `mret`
- **CSR:** `csrrw`, `csrrs`, `csrrc` and their immediate forms

The core implements precise traps for illegal instructions, breakpoints,
Machine-mode environment calls, and misaligned instruction/load/store addresses.
Instruction, load, and store access faults are implemented through portable
request/response ports. Machine software, timer, and external interrupt inputs
are implemented with standard `mstatus`, `mie`, `mip`, `mepc`, and `mcause`
behavior. The core also implements `mcycle`/`mcycleh` and
`minstret`/`minstreth`.

## Portable memory implementation

`risc_core.v` contains the five-stage CPU and no memory arrays or GPIO.
`risc_processor.v` is a compatibility wrapper around `simple_soc.v`, whose
`soc_memory.v` supplies synchronous ROM, shared executable RAM, and GPIO.
`memory_delay.v` supports registered responses and simulation delay injection.

The default map is 64 KiB ROM at `0x00000000`, 64 KiB RAM at `0x10000000`,
and the GPIO output/readback register at `0x40001000`. Other peripheral
windows currently fault. RAM survives reset. The original tests explicitly use
a legacy data-map option; new memory tests use the default map.

See [the implementation guide](docs/memory_interfaces.md) for handshake timing,
stall/flush behavior, fault handling, and verification details.

## Verification

The simulation flow uses a self-checking Verilog testbench and directed assembly programs under `tests/asm/`. `sim/build_tests.ps1` compiles each `.S` source with the RISC-V GCC toolchain, links it at address zero, converts the resulting binary into one 32-bit word per line, and writes the generated memory images under `sim/build/programs/`. The Verilog instruction memory loads those generated `.hex` files with `$readmemh`.

Each test checks final architectural state through register, memory, or MMIO LED scoreboards and exits with a failed simulator status on mismatch. The original `tests/*.hex` files are retained temporarily as reference fixtures while the assembly migration is validated.

Current directed tests:

| Test | Coverage |
| --- | --- |
| `alu.S` | R-type ops, immediate ops, and `x0` immutability |
| `memory.S` | `sw`, `lw`, memory addressing, dependent load result |
| `forwarding.S` | back-to-back EX/MEM and MEM/WB ALU forwarding |
| `load_use.S` | load-use hazard stall followed by dependent ALU ops |
| `branch_flush.S` | taken branch flushing wrong-path instructions |
| `store_forward.S` | forwarding ALU result into store data and reloading it |
| `upper_immediate.S` | `lui`, `auipc`, PC-relative results, and result forwarding |
| `jumps.S` | `jal`, `jalr`, PC+4 link values, target forwarding, and wrong-path flushing |
| `jump_backward.S` | backward J-type immediate sign extension and repeated branch execution |
| `compare.S` | signed and unsigned register/immediate comparisons |
| `shifts.S` | logical/arithmetic shifts, boundary amounts, and shift forwarding |
| `branches_all.S` | all branch conditions, taken/not-taken paths, forwarding, and load-to-branch stalls |
| `subword_memory.S` | byte/halfword loads and stores, extension, lane strobes, preservation, forwarding, and load-use stalls |
| `csr_mret.S` | CSR read/modify/write semantics, dependencies, and `mret` redirection |
| `fence_system.S` | `fence` retirement and `fence.i` pipeline refetch |
| `trap_*.S` | precise illegal, system, CSR, and address-misalignment traps |
| `trap_resume.S` | `mtvec` entry, trap CSR state, handler execution, and `mret` resume |
| `branch_misaligned_not_taken.S` | no exception for an untaken branch with a misaligned encoded target |
| `machine_interrupts.S` | interrupt masking, `mie`/`mip`, immediate entry, `mepc`, `MRET`, and MEI > MSI > MTI priority |
| `machine_interrupt_masking.S` | pending external interrupt held off by its local `mie` bit until enabled |
| `machine_branch_interrupt.S` | precise interrupt entry across a taken branch redirect |
| `machine_memory_interrupt.S` | precise timer interrupts during outstanding stores and loads |
| `machine_counters.S` | monotonic 64-bit `mcycle` and `minstret` CSR halves |

Run the regression with Icarus Verilog:

```powershell
powershell -ExecutionPolicy Bypass -File sim\run_tests.ps1
```

The regression first runs the assembly build automatically, then compiles and runs the Verilog simulation. To generate programs without simulating them:

```powershell
powershell -ExecutionPolicy Bypass -File sim\build_tests.ps1
```

Tests stop after their expected instruction-retirement sequence completes, with
the cycle limit retained as a deadlock timeout. To print each retired instruction
and its register or store effect, enable the optional trace:

```powershell
powershell -ExecutionPolicy Bypass -File sim\run_tests.ps1 -Trace
```

You should see each directed test print `TEST <name> PASS`, followed by:

```text
221 simulations passed; retirement/trap traces agree across latency configurations.
```

The SoC ROM includes the original Fibonacci/MMIO LED program as its default
image when no `+PROGRAM=...` plusarg is provided. Its LED output uses the
aligned GPIO address `0x4000_1000`.

The full regression runs 43 directed scenarios in five latency configurations, plus two
outstanding-transaction reset runs, two wrong-path fetch-error runs, and an
adapter backpressure/bounds test and a dual-port RAM collision test. It compares architectural event traces across
latencies and compiles RTL using Verilog-2005 mode. For a shorter run use
`sim/run_tests.ps1 -Quick`; logs are written under `sim/build/`.

The RAM now uses dedicated synchronous read registers and post-register response
selection to support block RAM inference, without reducing its 64 KiB capacity.
All 221 simulations pass. RAM mapping and 100 MHz timing were verified before
the Machine-interrupt/counter expansion. Per request, Vivado has not yet been
rerun for the expanded RTL. See [RAM inference changes and
verification](docs/bram_inference.md).
See
[Vivado Tcl Store troubleshooting](docs/vivado_troubleshooting.md) for the
previous environment failure and recovery steps.

## Timing And FPGA Flow

Vivado build scripts target the Basys 3 Artix-7 `xc7a35tcpg236-1`.

Last recorded post-implementation result from Vivado 2025.2, immediately before
the current Machine-interrupt/counter expansion:

| Metric | Result |
| --- | --- |
| Clock constraint | 10.000 ns / 100 MHz |
| Worst setup slack | +0.069 ns |
| Total negative slack | 0.000 ns |
| Worst hold slack | +0.101 ns |
| Timing status | All user-specified timing constraints met |

These figures are a baseline, not a timing claim for the newly expanded RTL.
Vivado implementation must be rerun before the Machine-mode milestone receives
FPGA timing sign-off.

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

The timing and utilization results must be regenerated after the current RTL
changes before they are treated as current implementation results.

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
|   |-- csr_file.v
|   |-- risc_processor.v
|   |-- risc_core.v
|   |-- simple_soc.v
|   |-- soc_memory.v
|   |-- memory_delay.v
|   `-- top_basys3.v
|-- sim/
|   |-- build_tests.ps1
|   |-- tb_risc_processor.v
|   `-- run_tests.ps1
|-- tests/
|   |-- asm/
|   |   |-- alu.S
|   |   |-- memory.S
|   |   |-- forwarding.S
|   |   |-- load_use.S
|   |   |-- branch_flush.S
|   |   |-- store_forward.S
|   |   |-- upper_immediate.S
|   |   |-- jumps.S
|   |   |-- jump_backward.S
|   |   |-- compare.S
|   |   |-- shifts.S
|   |   |-- branches_all.S
|   |   `-- subword_memory.S
|   `-- link.ld
|-- docs/
|   `-- architecture.md
|-- basys3.xdc
|-- constraints.xdc
|-- build.tcl
|-- build_bitstream.tcl
|-- sim.tcl
`-- README.md
```

## License

MIT License
