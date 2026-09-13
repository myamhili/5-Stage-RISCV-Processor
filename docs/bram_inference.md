# RAM inference rewrite

## Why it was needed

The previous synthesis completed, but placement rejected 16,384 RAMD64E cells
against 9,600 available compatible sites on the selected xc7a35t. Synthesis
message 8-6851 reported byte write enables without a recognized RAM output
register. The old read registers also selected ROM, GPIO and default data.

## Implementation

`rtl/soc_memory.v` keeps the same interfaces, default 64 KiB RAM capacity,
memory map, byte writes, initialization and reset behavior. No vendor primitive
or new ISA encoding was introduced.

The RAM array now feeds two dedicated synchronous registers: one for instruction
reads, one for the data read/write port. The data port uses read-first byte-lane
writes. ROM reads and GPIO snapshots have separate registers. RAM storage and
read registers have no runtime reset; response validity makes stale data
irrelevant after reset.

On a request-acceptance clock edge, the selected data and response target are
registered together. A combinational mux selects among those registered outputs.
The existing response-valid register updates on the same edge. This preserves
the registered response latency without accidentally adding a stale-data cycle.
No new request is accepted while that channel's response is pending, so target,
data and error stay stable under backpressure. GPIO uses a snapshot, not its
live value, in a pending response.

Indices use the number of address bits required by the configured depth. Full
32-bit range and alignment checks still gate accesses before truncation, so
invalid addresses cannot wrap into valid memory. Legacy data-map tests retain
their original low-address mapping.

Simultaneous same-word instruction reads and data writes are serialized: the
write is accepted first and instruction ready stays low for that cycle. This
avoids depending on FPGA cross-port collision behavior. Other-word accesses and
read/read accesses may proceed together. A RAM instruction response already
pending remains unchanged even if the data port subsequently overwrites its word.
FENCE.I is still required for software code updates and instruction refetch.

## Verification completed

The full Verilog-2005 regression now passes 221 simulations, including the
Machine-interrupt/counter expansion. The added
`sim/tb_ram_ports.v` checks collision arbitration, byte preservation, read/read
and different-word concurrency, blocked response stability during a later write,
ROM/RAM response selection, invalid instruction addresses and transaction counts.
Existing delayed-memory, precise-fault, reset and executable-RAM tests also pass.

## Vivado verification status

Before the Machine-interrupt/counter expansion, the standalone routed check
confirmed 16 block-RAM primitives for the main RAM, setup WNS +0.069 ns, TNS
0.000 ns, and hold slack +0.101 ns at 100 MHz. Those results remain evidence for
the memory rewrite, but they are not timing sign-off for the newly expanded RTL.
Per request, Vivado has not yet been rerun after the Machine-mode changes.

Run the standalone check from PowerShell in the repository:

```powershell
& 'C:/AMDDesignTools/2025.2/Vivado/bin/vivado.bat' -mode batch -source sim/check_bram.tcl -log sim/build/bram_check.log -journal sim/build/bram_check.jou
```

Alternatively, in a fresh working Vivado Tcl session with no project open:

```tcl
cd {C:/Users/Hyun/Documents/GitHub/Simple RISC Processor}
source sim/check_bram.tcl
```

Save any open project before closing it. The check uses an in-memory project and
does not overwrite existing GUI project runs. Its own reports/checkpoint under
`sim/build/bram_check` are replaced on subsequent successful runs.

Inspect `utilization_synth.rpt` for the main RAM's block RAM mapping, and
`utilization_routed.rpt`, `timing_routed.rpt` and `drc_routed.rpt` after routing.
The script rejects absent main-RAM BRAM primitives and negative setup/hold slack.
It targets the existing 100 MHz out-of-context constraints, not physical board
pins. A successful run does not verify board I/O timing, a bitstream, or hardware.

Do not disable resource-overflow DRCs or assume old timing reports apply to this
rewrite. If inference still fails, use the new synthesis messages to refine the
memory template before considering a board-specific wrapper or smaller memory.
