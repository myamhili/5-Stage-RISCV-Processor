# Portable memory milestone: implementation and verification

## What changed

The processor still has IF, ID, EX, MEM and WB stages. Memory latency is now
explicit rather than assumed to be zero. No ISA encodings changed.

- `rtl/risc_core.v`: CPU, decoder, register file, ALU, CSRs, retirement and traps.
- `rtl/simple_soc.v`: connects the CPU to memory through two delay adapters.
- `rtl/soc_memory.v`: ROM, shared instruction/data RAM, address decoding and GPIO.
- `rtl/memory_delay.v`: one-entry request/response bridge with reproducible
  simulation delays. Synthesis uses the parameterized fixed-delay configuration.
- `rtl/risc_processor.v`: retains the original external integration ports.
- Legacy `pc.v`, `instruction_memory.v`, and `data_memory.v` are retained as
  reference modules but are not instantiated by the new CPU/SoC.

The synthesis-facing path was elaborated with Icarus in Verilog-2005 mode with
SYNTHESIS defined. This is not FPGA synthesis or a timing/BRAM inference result.

## Handshake contract

A transaction has two transfers, sampled on rising clock edges:

1. Request: req_valid AND req_ready.
2. Response: rsp_valid AND rsp_ready.

Each interface has at most one accepted, uncompleted request. A response must
arrive after the request edge, never on the same edge. The minimum-latency
configuration has zero *additional* wait cycles; it still has registered
responses. The SoC bridge adds a response register after the memory read.

Once valid is presented, its payload must remain stable until accepted.
A response sender similarly holds valid, data and error while ready is low.
Exactly one response follows each request, including stores.

Both endpoints share reset. Reset clears transaction state but does not roll
back stores already accepted by a memory. RAM contents survive reset. A future
external controller must provide an equivalent drain/reset agreement.

## Fetch controller

FETCH_IDLE reserves the IF/ID slot and captures the next PC into fetch_address.
FETCH_REQUEST holds the address until accepted. FETCH_RESPONSE consumes the
response when IF/ID is free or its previous instruction is advancing.

A redirect invalidates IF/ID and marks a presented or outstanding fetch as
discarded. The request still completes its handshake. Its response is consumed
without executing the data or reporting its error. The redirect target is saved
in the next-PC register and fetched after the old transaction drains.

Same-edge response/redirect handling checks the current flush signal as well as
the registered discard flag. Redirects never overwrite an unaccepted request's
address.

Fetch errors become IF/ID metadata, retaining the requested PC. EX recognizes
this metadata before decoding a placeholder instruction. A stale fetch error
cannot become a trap.

This conservative front end does not sustain one instruction per cycle even
with minimum latency. Throughput optimization is deliberately a later change.

## Data controller and pipeline state

EX/MEM owns a load or store until its response transfers. dmem_request_sent
records acceptance so a held store cannot be issued twice.

During this wait:
- IF/ID and ID/EX hold their instructions.
- EX/MEM retains the complete memory operation.
- Older WB instructions retire and WB becomes invalid instead of repeating.
- Forwarded register operand values are captured into held ID/EX operand
  registers, so draining WB cannot remove the only correct operand value.

On the response edge the memory instruction transfers to WB and EX/MEM becomes
empty. EX resumes on the next cycle, when load data can be forwarded from WB.
This deliberately introduces a completion bubble to keep the control simple.

A held EX branch, jump, MRET or FENCE.I cannot redirect repeatedly: normal
redirect generation is disabled while MEM is occupied or an older fault exists.

## Addresses, byte lanes, and ordering

The CPU retains the original effective byte address in the pipeline and reports
it at retirement or in mtval. The bus receives its aligned word address.
Store data is shifted into byte lanes and wstrb selects which lanes to write.
Loads receive a complete aligned word, then select and sign/zero extend bytes.

Reads always access a full word. GPIO reads have no side effects. Peripherals
that need access-size-sensitive reads require an interface extension or a
documented word-read policy before integration.

The SoC checks bounds and permissions before performing a write. ROM writes,
unmapped writes and malformed unaligned bus writes return errors with no target
modification. A peripheral bridge must preserve this store-error guarantee.

FENCE executes in an in-order stream with no posted stores: older memory
operations already completed. FENCE.I additionally flushes and refetches.
Both instruction and data ports reach the same RAM array, so stores can change
code subsequently fetched after FENCE.I. If a data write and instruction request
target the same RAM word, the data write wins and instruction acceptance waits.
Software must still use FENCE.I to discard previously fetched instructions.

## Fault priority

Instruction/load/store access faults use causes 1/5/7. mepc is the faulting
instruction's PC, and mtval is the original effective address (the requested
instruction address for fetch faults). The failed instruction does not retire.

Alignment is checked before issuing data requests. A misaligned access produces
cause 4 or 6 without touching the bus. A load into x0 still accesses memory and
can fault.

An unresolved older MEM operation prevents younger EX exceptions and redirects
from executing. A failing MEM response flushes younger stages and becomes the
WB trap record. Existing trap entry updates the Machine CSRs and redirects to
mtvec. This preserves instruction-age ordering.

## Default map and initialization

| Region | Default range | Access |
| --- | --- | --- |
| ROM | 0x00000000-0x0000ffff | instruction/data reads |
| RAM | 0x10000000-0x1000ffff | instruction reads, data reads/writes |
| GPIO | 0x40001000-0x40001003 | output register with byte writes and readback |

Reserved UART/timer/interrupt windows and unused GPIO offsets return errors.
Those peripherals and interrupts are later milestones.

simple_soc parameters:
- RESET_VECTOR: default 0; must be instruction aligned.
- ROM_WORDS/RAM_WORDS: default 16384 words each.
- RAM_BASE: default 0x10000000; use a word-aligned, non-overlapping range.
- INIT_FILE: optional word-per-line ROM image for simulation or FPGA initialization.
- LEGACY_DATA_MAP: default 0. Set to 1 only to run the old low-address RAM fixtures.

The built-in boot program uses 13 ROM words; configure at least that many when
using it. RAM test initialization is enabled only by LEGACY_DATA_MAP.
Arrays initialize once and are never cleared by an asynchronous reset loop.
Synthesis must still confirm the desired memory inference for the selected FPGA.

## Verification commands

Run from the repository root:

```powershell
powershell -ExecutionPolicy Bypass -File sim\run_tests.ps1
powershell -ExecutionPolicy Bypass -File sim\run_tests.ps1 -Quick
powershell -ExecutionPolicy Bypass -File sim\run_tests.ps1 -Trace
```

The full run performs 221 simulations:
- Original 26 assembly programs plus Fibonacci in five configurations: 135.
- Nine Machine interrupt/counter scenarios in five configurations: 45.
- Seven new memory/permission/FENCE.I programs in five configurations: 35.
- Reset with instruction/data transactions outstanding: 2.
- Stale fetch errors with immediate/delayed request acceptance: 2.
- Adapter response backpressure, byte lanes and address boundaries: 1.
- Dual-port RAM collisions, concurrent accesses and held instruction responses: 1.

The five configurations are minimum, fixed delays, and seeds 1, 17 and 12345.
Random delays are bounded at eight extra cycles. Each program's ordered
architectural events must match its minimum-latency reference, ignoring timing.
The comparison is between timing configurations of this RTL, not an independent
ISA reference model or certification suite.

bus_monitor checks stable blocked requests/responses, transaction conservation,
and the single-outstanding rule. Memory tests count stores and ensure retirement
follows successful responses. New fault tests inspect mepc/mcause/mtval and
check that rejected writes leave ROM/RAM/GPIO unchanged.

Logs are retained under sim/build/<configuration>-<test>.log.
The -Quick option runs the minimum configuration and directed protocol/reset
checks. Precise old load-use stall counts are no longer asserted because fetch
latency changes instruction spacing; architectural outcomes remain checked.

## Remaining work

The RAM inference rewrite was subsequently confirmed in a routed Vivado check.
See [the RAM inference handoff](bram_inference.md). That result predates the
Machine-mode changes and therefore remains only their timing baseline.
Machine interrupts and counters are now implemented and pass the Icarus
regression across the memory-latency matrix. Their post-implementation Vivado
timing check remains intentionally deferred. The M extension, UART/timer MMIO
devices, and independent architecture testing remain separate milestones.
Existing PDFs describe the overall roadmap and were not regenerated.
