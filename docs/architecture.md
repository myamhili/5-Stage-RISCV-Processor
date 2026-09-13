# Portable RISC-V Processor Architecture Contract

## 1. Purpose and status

This document defines the target architecture for evolving this repository from
its current RV32I subset into a complete, portable bare-metal RISC-V processor.
It is the contract for future RTL, tests, firmware, and FPGA wrappers.

The target is:

```text
RV32IM_Zicsr_Zifencei
```

The processor is a single-hart, 32-bit, little-endian, in-order implementation
with Machine mode, precise traps, and separate instruction and data interfaces.
Linux support, Supervisor mode, an MMU, caches, and other optional extensions are
outside the first complete release.

The current RTL does not yet implement this entire contract. Section 14 records
the known differences so they can be removed deliberately.

## 2. HDL and portability rules

- Synthesizable processor RTL remains Verilog in `.v` files.
- Core RTL uses ordinary Verilog modules, parameters, wires, registers, and
  flattened ports.
- The core does not require SystemVerilog `interface`, `struct`, class, or package
  constructs.
- Testbenches may use simulator-supported verification features, but synthesizable
  RTL must remain accepted by Icarus Verilog and Xilinx Vivado.
- The CPU and generic SoC must not instantiate a board-specific pin, clock, DDR,
  UART, or FPGA primitive.
- Xilinx primitives are permitted only in explicitly named adapters or
  board-specific top-level modules.
- All board-specific pin constraints remain outside the CPU and generic SoC.

## 3. Architectural state

The hart exposes the architectural state required by RV32:

- 32 integer registers `x0` through `x31`, each 32 bits wide.
- `x0` always reads as zero and ignores writes.
- A 32-bit program counter.
- Implemented Machine-mode control and status registers.
- Memory is byte-addressed and little-endian.
- Instructions are 32 bits wide and must be aligned to a 4-byte boundary.

The core initially implements only Machine mode. It does not implement User or
Supervisor mode in the first complete release.

## 4. ISA requirements

### 4.1 RV32I

The completed core implements all required RV32I behavior, including:

- Integer arithmetic, comparison, logical, and shift instructions.
- Immediate arithmetic, comparison, logical, and shift instructions.
- `LUI` and `AUIPC`.
- `JAL` and `JALR`.
- All six conditional branch operations.
- Byte, halfword, and word loads and stores with the required sign or zero
  extension.
- `FENCE`.
- `ECALL` and `EBREAK` as synchronous traps.
- Illegal-instruction detection for unsupported or reserved encodings.

Unsupported `funct3`, `funct7`, opcode, shift encoding, CSR access, or privileged
operation must raise an illegal-instruction exception. It must never silently
fall back to an arithmetic operation.

### 4.2 M extension

The completed core implements:

- `MUL`, `MULH`, `MULHSU`, and `MULHU`.
- `DIV`, `DIVU`, `REM`, and `REMU`.
- Architecturally defined division-by-zero and signed-overflow results.

The multiplier/divider may be iterative and multi-cycle. Its latency is not
architecturally visible except through performance counters.

### 4.3 Zicsr and Zifencei

The completed core implements all six CSR read/modify/write instructions:

- `CSRRW`, `CSRRS`, and `CSRRC`.
- `CSRRWI`, `CSRRSI`, and `CSRRCI`.

`FENCE.I` synchronizes later instruction fetches with earlier stores visible to
the hart. A cacheless implementation may satisfy this by draining older memory
operations, flushing prefetched instructions, and refetching from the next PC.

## 5. Pipeline contract

The implementation remains a five-stage in-order pipeline:

```text
IF -> ID -> EX -> MEM -> WB
```

Every pipeline stage carries an explicit valid bit. An invalid stage represents
a bubble and cannot modify architectural state.

The implementation must provide:

- EX/MEM and MEM/WB operand forwarding.
- Correct store-data forwarding.
- Load-use hazard detection and stalling.
- Redirect and flush behavior for taken branches, jumps, traps, and `MRET`.
- Complete stalling for outstanding instruction or data transactions when
  required.
- Multi-cycle EX stalling for the M extension.

Pipeline control must preserve in-order architectural effects. In particular:

- A killed instruction cannot write a register, CSR, memory location, or MMIO
  device.
- A store is issued at most once.
- A faulting instruction cannot produce its normal destination side effect.
- Younger instructions are flushed when an older instruction traps.
- An interrupt is taken only at a precise instruction boundary.

When control requests coincide, the implementation uses this architectural
priority:

1. Reset.
2. The oldest synchronous exception.
3. An enabled interrupt at a precise instruction boundary.
4. `MRET`, jump, or taken-branch redirect from the oldest eligible instruction.
5. Memory or multi-cycle execution stall.
6. Load-use stall and ordinary sequential execution.

Instruction age constrains this ordering: a younger EX exception or redirect
cannot bypass an unresolved older MEM transaction. A MEM access fault kills
younger instructions before they can advance or issue side effects. An older
redirect cancels younger fetch faults. Interrupt support remains future work.

## 6. Clock and reset contract

- The portable core has one clock input named `clk`.
- The portable core has an active-high reset input named `rst`.
- Board wrappers translate the physical reset polarity and synchronize its
  release to `clk`.
- The target core uses synchronous reset behavior internally. Migration from the
  current asynchronous reset style is an explicit implementation task.
- Reset clears outstanding transactions and all pipeline valid bits.
- Reset initializes the PC to the parameter `RESET_VECTOR`.
- `RESET_VECTOR` defaults to `32'h0000_0000`.
- Architectural integer registers read as zero after reset.
- Reset values for implemented CSRs follow the privileged architecture or are
  documented where the specification permits an implementation choice.

No architectural behavior depends on a fixed clock frequency. Timers receive a
documented clock-frequency parameter from the containing SoC or board wrapper.

## 7. Instruction memory interface

The core uses a flattened, single-outstanding-transaction Verilog interface.
Signal names below define the intended contract; exact top-level naming may add a
consistent prefix.

### Request channel

```text
output        imem_req_valid
input         imem_req_ready
output [31:0] imem_req_addr
```

### Response channel

```text
input         imem_rsp_valid
output        imem_rsp_ready
input  [31:0] imem_rsp_data
input         imem_rsp_error
```

Rules:

- A request is accepted when `imem_req_valid && imem_req_ready` is true on a
  rising clock edge.
- Request fields remain stable while valid is asserted and ready is low.
- Exactly one response follows each accepted request.
- Responses arrive no earlier than the cycle after request acceptance.
- Both endpoints share reset, which abandons outstanding transactions.
- `imem_req_addr` is a byte address and is 4-byte aligned.
- The core permits at most one outstanding instruction transaction initially.
- A redirect may make an outstanding response stale. The core must consume and
  discard that response without executing it.
- This also applies to a request whose valid signal is already presented but
  which has not yet been accepted: its address and valid remain stable.
- `imem_rsp_error` raises an instruction access-fault exception for the associated
  fetch.

## 8. Data memory interface

The data interface is also flattened and permits one outstanding transaction.
All bus transactions operate on one aligned 32-bit word. The core performs byte
lane selection and load extension.

### Request channel

```text
output        dmem_req_valid
input         dmem_req_ready
output        dmem_req_write
output [31:0] dmem_req_addr
output [31:0] dmem_req_wdata
output [3:0]  dmem_req_wstrb
```

### Response channel

```text
input         dmem_rsp_valid
output        dmem_rsp_ready
input  [31:0] dmem_rsp_rdata
input         dmem_rsp_error
```

Rules:

- A request is accepted when `dmem_req_valid && dmem_req_ready` is true on a
  rising clock edge.
- Request fields remain stable while valid is asserted and ready is low.
- Exactly one response follows every accepted read or write request.
- Responses arrive no earlier than the following cycle. Both endpoints must
  clear transaction state on a shared reset.
- `dmem_req_addr` is the aligned word address; its bottom two bits are zero.
- `dmem_req_wstrb[n]` selects byte lane `n`. It is zero for reads.
- Stores are not architecturally complete until their response is accepted.
- A responder returning a store error must not have modified the target.
- Reset cannot undo an already accepted store. RAM contents survive reset.
- `dmem_rsp_error` raises a load or store access-fault exception as appropriate.
- The core must not issue a bus request for an access that it has already
  determined is misaligned.

The single-outstanding limitation keeps the first implementation simple. A later
adapter may add buffering without changing architectural behavior.

## 9. Alignment and access faults

- Instruction addresses must be aligned to 4 bytes.
- `JAL`, `JALR`, and taken branches with a misaligned target raise an
  instruction-address-misaligned exception on the control-flow instruction.
- Halfword accesses require address bit 0 to be zero.
- Word accesses require address bits 1:0 to be zero.
- Misaligned loads and stores trap; the core does not split them into multiple
  memory transactions.
- Bus response errors become instruction, load, or store access faults.
- `mtval` contains the faulting virtual/effective byte address for address and
  access faults.

## 10. Machine mode and precise traps

The final target's minimum Machine-mode CSRs are:

- `mstatus`
- `misa`
- `mie` and `mip`
- `mtvec`
- `mscratch`
- `mepc`
- `mcause`
- `mtval`
- `mcycle`
- `minstret`

Read-only identification CSRs may return zero where permitted. Access to an
unimplemented CSR or an illegal write to a read-only CSR raises an
illegal-instruction exception.

The core supports these synchronous exceptions at minimum:

- Instruction address misaligned.
- Instruction access fault.
- Illegal instruction.
- Breakpoint.
- Load address misaligned.
- Load access fault.
- Store/AMO address misaligned.
- Store/AMO access fault.
- Environment call from Machine mode.

The core supports Machine software, timer, and external interrupts. Interrupts
are qualified by `mstatus`, `mie`, and `mip` and are taken according to the
Machine-level privileged specification.

The three level-sensitive inputs map to `mip`/`mie` bits 3 (software), 7
(timer), and 11 (external). If several are eligible, priority is external,
software, then timer. Their `mcause` values are `0x80000003`, `0x80000007`,
and `0x8000000B`; interrupt `mtval` is zero. The supplying peripheral clears a
pending interrupt by deasserting its input.

On a trap:

- `mepc` identifies the interrupted or faulting instruction as required.
- `mcause` identifies the exception or interrupt.
- `mtval` records the required address or instruction information.
- Control transfers through `mtvec`.
- All younger pipeline stages are invalidated.
- The trap is precise: earlier instructions are complete and later instructions
  have no architectural effect.

`MRET` restores Machine interrupt state and redirects execution to `mepc`.

`minstret` increments only for instructions that retire normally. A synchronous
exception does not increment it for the faulting instruction.
`mcycle` increments every non-reset cycle, including memory stalls. Both
counters are 64 bits and are exposed through their low and high Machine CSR
halves on RV32.

## 11. Verification and retirement interface

The processor exposes a non-invasive verification interface in simulation and,
optionally, at the synthesizable core boundary.

### Normal retirement event

```text
output        retire_valid
output [31:0] retire_pc
output [31:0] retire_instruction
output        retire_rd_we
output [4:0]  retire_rd_addr
output [31:0] retire_rd_data
output        retire_mem_valid
output        retire_mem_write
output [31:0] retire_mem_addr
output [31:0] retire_mem_wdata
output [3:0]  retire_mem_wstrb
```

`retire_valid` is asserted for one cycle when one non-trapping instruction
retires. Register and memory fields describe the architectural effects of that
instruction. Writes to `x0` report `retire_rd_we` as zero.

### Trap event

```text
output        trap_valid
output [31:0] trap_pc
output [31:0] trap_instruction
output [31:0] trap_cause
output [31:0] trap_tval
```

`trap_valid` is asserted for one cycle when a synchronous exception or interrupt
is taken. A faulting instruction produces a trap event, not a normal retirement
event.

An interrupt is taken between instructions. Consequently, `retire_valid` may
be asserted in the same cycle as an interrupt trap: the reported instruction
retires first and interrupt `trap_pc`/`mepc` identifies its architectural
successor. This simultaneous condition is not permitted for a synchronous
exception.

The verification interface does not participate in pipeline control and may be
removed or left unconnected in a board wrapper.

The required verification ladder is:

1. Existing directed regression tests.
2. Per-instruction assembly tests.
3. Hazard and redirect interaction tests.
4. Fixed and randomized memory-latency tests.
5. Reference-model trace or signature comparison.
6. Applicable official RISC-V architecture tests.
7. Vivado synthesis, timing, and utilization checks.

## 12. Generic SoC and memory map

The CPU core does not contain the SoC address decoder. The generic SoC initially
uses this default map:

| Address range | Size | Function |
| --- | ---: | --- |
| `0x0000_0000` - `0x0000_FFFF` | 64 KiB | Boot ROM |
| `0x1000_0000` - `0x1000_FFFF` | 64 KiB | On-chip RAM |
| `0x4000_0000` - `0x4000_0FFF` | 4 KiB | UART |
| `0x4000_1000` - `0x4000_1FFF` | 4 KiB | GPIO, including LEDs |
| `0x4000_2000` - `0x4000_2FFF` | 4 KiB | Machine timer |
| `0x4000_3000` - `0x4000_3FFF` | 4 KiB | Interrupt/test control |

Memory sizes are implementation parameters, but their base addresses remain
stable for the first complete release. Unmapped accesses return a bus error and
therefore generate the appropriate access-fault exception.

The final generic SoC is planned to provide:

- Boot ROM and on-chip RAM adapters.
- A simple UART.
- GPIO suitable for LEDs, buttons, and headers.
- A 64-bit machine timer with a compare register and interrupt output.
- Machine software and external interrupt inputs or simple test registers.

Currently the GPIO output/readback register occupies only 0x40001000-0x40001003.
The core-level software, timer, and external interrupt inputs are present, but
their MMIO source devices are not. The remaining peripheral windows are
reserved and return access faults. UART, timer, and interrupt-controller devices
are future SoC work.

## 13. Board integration boundary

The portable hierarchy is:

```text
RISC-V CPU core
    -> generic instruction/data interfaces
    -> generic SoC and memory/peripheral adapters
    -> board-specific Xilinx wrapper
```

A new Xilinx board may require changes to:

- The top-level wrapper.
- The Vivado target part.
- XDC pin and timing constraints.
- Clock generation and reset synchronization.
- Physical UART, LEDs, buttons, and other I/O.
- Optional BRAM, DDR, or other Xilinx IP adapters.

It must not require changes to instruction decode, the pipeline, register file,
ALU, CSR/trap logic, or architectural verification.

A physical board is not required to complete the CPU. Simulation, reference
comparison, architecture tests, lint, and synthesis establish core correctness.
Hardware is later used to validate the selected board's physical clock, reset,
pins, external memory, and peripherals.

## 14. Current implementation differences

The current regression includes directed assembly tests for RV32I arithmetic,
control flow, subword memory, CSR operations, fences, precise synchronous traps,
and trap-handler resume, plus the default Fibonacci/MMIO program. It intentionally
does not yet implement the entire final target.
Known differences include:

- RV32I, Zicsr, Zifencei, Machine-mode synchronous trap entry, and `MRET` are
  implemented. The M extension is not yet implemented.
- The portable five-stage CPU is in `rtl/risc_core.v`. `simple_soc.v` supplies
  registered ROM/RAM/GPIO responses through single-outstanding handshakes.
- Default ROM and shared executable RAM are 64 KiB each. Sizes, RAM base,
  reset vector and ROM initialization file are parameters.
- Byte, halfword, and word loads/stores are implemented for aligned accesses;
  misaligned data and control-flow addresses raise precise traps.
- The LED uses the aligned GPIO address `0x4000_1000`; the full generic GPIO
  peripheral block is not yet implemented.
- Instruction/load/store access faults (1/5/7) are implemented, including
  stale fetch response discard and precise MEM fault handling.
- Pipeline valid bits, retirement signals, minimal Machine CSRs, and precise
  synchronous trap outputs are implemented. Interrupts, counters, and
  M-extension operations are not yet implemented.
- Internal reset logic currently uses asynchronous reset sensitivity.
- The Basys 3 wrapper directly connects the physical reset button to the core.

These differences are migration work, not exceptions to the target contract.

The original assembly regression uses an explicit test-only
`LEGACY_DATA_MAP=1` option to preserve its low-address RAM fixtures. The board
wrapper and new memory milestone tests use the default documented map.
See [memory_interfaces.md](memory_interfaces.md) for implementation and tests.

## 15. Phase gates

Implementation proceeds only with a green regression at each gate:

1. **Contract gate:** this document and baseline results are present.
2. **Observability gate:** retirement/trap outputs and assembler-driven tests work.
3. **RV32I gate:** applicable RV32I architecture tests pass.
4. **Memory gate:** randomized response latency preserves architectural results.
5. **Machine gate:** CSR, exception, interrupt, and `MRET` tests pass.
6. **RV32M gate:** applicable M-extension architecture tests pass.
7. **SoC gate:** compiled C firmware exercises UART, timer interrupts, and GPIO.
8. **Release gate:** automated regression, documentation, and representative
   Xilinx synthesis/timing checks pass.
