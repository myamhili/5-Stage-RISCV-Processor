# Resolving the Vivado Tcl Store startup problem

## What failed

The previous Vivado log reported two startup errors:

- `Common 17-1297`: the user Tcl Store catalog under `C:/Users/Hyun/AppData/Roaming/Xilinx/Vivado/2025.2/XilinxTclStore` is corrupted. The message recommends `tclapp::reset_tclstore`.
- `Common 17-539`: Vivado could not load `::tclapp::support::appinit 1.2` from its installed Tcl Store.

These errors occurred before RTL processing. They do not establish a Verilog design error, and fixing them does not establish that FPGA synthesis or timing will pass.

Read-only inspection found both `pkgIndex.tcl` and `appinit.tcl` under `C:/AMDDesignTools/2025.2/Vivado/data/XilinxTclStore/support/appinit`. The package index registers version 1.2. Therefore, do not assume that the installed package files are missing. The user-cache directory could not be inspected in this session; that alone does not establish a Windows permissions problem.

No Vivado commands or installation repairs were performed during this implementation.

## 1. Reset the user Tcl Store

Close other Vivado sessions. If you have custom Tcl Store applications, back them up first; resetting the store may require reinstalling them.

Open Vivado and enter the following in its **Tcl Console**, not PowerShell:

```tcl
tclapp::reset_tclstore
exit
```

Restart Vivado and check whether the startup errors are gone. This is the first remedy because the original Vivado error explicitly requests it.

## 2. If the reset command cannot run

With all Vivado sessions closed, use File Explorer to locate:

```text
C:\Users\Hyun\AppData\Roaming\Xilinx\Vivado\2025.2\XilinxTclStore
```

Rename only that `XilinxTclStore` folder to an unused backup name, such as `XilinxTclStore.backup-20260905`. Do not delete it or rename the parent Vivado directory. Restart Vivado so it can attempt to initialize a fresh user store. Keep the backup until the problem is resolved; it preserves the previous cache and any user-installed applications.

If the exact directory does not exist or Windows refuses the rename, stop and record the message instead of deleting other folders or broadly changing permissions.

## 3. Diagnose the installed package if the error remains

In the Vivado Tcl Console, run:

```tcl
set appinit_dir {C:/AMDDesignTools/2025.2/Vivado/data/XilinxTclStore/support/appinit}
puts [file exists [file join $appinit_dir pkgIndex.tcl]]
puts [file exists [file join $appinit_dir appinit.tcl]]
lappend auto_path $appinit_dir
package require ::tclapp::support::appinit 1.2
```

The first two checks should print `1`. A successful package load should return its version. Adding this directory to `auto_path` is a **session-only diagnostic**, not a verified permanent repair.

- If loading succeeds only after adding the directory, inspect Tcl search-path customization and startup scripts. Check whether `TCLLIBPATH`, `TCL_LIBRARY`, or `XILINX_TCLAPP_REPO` overrides point at another installation. Record their values before making any changes; do not remove unrelated environment settings blindly.
- If loading still fails, save the full console error. Existing files do not rule out a damaged dependency or installation. Use the AMD installer’s supported repair/reinstall workflow for this Vivado version, or provide the startup log to AMD support.
- Do not delete the installed `data/XilinxTclStore` tree or download replacement Tcl files from untrusted sites.

The [official Xilinx Tcl Store repository](https://github.com/Xilinx/XilinxTclStore) provides background on this package system. The steps above are troubleshooting guidance, not confirmation that a repair has succeeded on this computer.

## 4. Resume project verification

Once Vivado starts without the Tcl Store errors, open PowerShell in the project directory and run the existing project build:

```powershell
vivado -mode batch -source build.tcl
```

If `vivado` is not on PATH, launch the Vivado-provided command environment or use the installed Vivado launcher with its full path. Review the new log: an RTL, synthesis, constraints, or timing failure after initialization is a separate problem and should be diagnosed from that new message.

This implementation passed Icarus Verilog simulation and a Verilog-2005 top-level compile with `SYNTHESIS` defined. That compile is not synthesis, implementation, timing closure, or hardware validation. No FPGA board is needed for those software checks, but the selected FPGA part, clocking, pin constraints, and board wrapper must be reviewed before programming a board.
