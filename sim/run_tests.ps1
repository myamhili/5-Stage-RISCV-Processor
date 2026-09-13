param(
    [switch]$Trace,
    [switch]$Quick
)

$ErrorActionPreference = "Stop"

$rtl = @(
    "sim/bus_monitor.v",
    "rtl/control_unit.v",
    "rtl/register_file.v",
    "rtl/alu.v",
    "rtl/csr_file.v",
    "rtl/risc_core.v",
    "rtl/memory_delay.v",
    "rtl/soc_memory.v",
    "rtl/simple_soc.v",
    "rtl/risc_processor.v",
    "sim/tb_risc_processor.v"
)

$tests = @(
    @{ Name = "alu"; Words = 10; Retirements = 10 },
    @{ Name = "memory"; Words = 7; Retirements = 7 },
    @{ Name = "forwarding"; Words = 7; Retirements = 7 },
    @{ Name = "load_use"; Words = 6; Retirements = 6 },
    @{ Name = "branch_flush"; Words = 8; Retirements = 6 },
    @{ Name = "store_forward"; Words = 8; Retirements = 8 },
    @{ Name = "upper_immediate"; Words = 7; Retirements = 7 },
    @{ Name = "jumps"; Words = 11; Retirements = 7 },
    @{ Name = "jump_backward"; Words = 10; Retirements = 10 },
    @{ Name = "compare"; Words = 18; Retirements = 18 },
    @{ Name = "shifts"; Words = 16; Retirements = 16 },
    @{ Name = "branches_all"; Words = 41; Retirements = 32; MaxCycles = 80 },
    @{ Name = "subword_memory"; Words = 50; Retirements = 50; MaxCycles = 90 },
    @{ Name = "csr_mret"; Words = 21; Retirements = 19; MaxCycles = 60 },
    @{ Name = "fence_system"; Words = 6; Retirements = 6 },
    @{ Name = "trap_illegal"; Words = 2; TrapCause = 2; TrapPc = "00000000"; TrapTval = "ffffffff" },
    @{ Name = "trap_ecall"; Words = 2; TrapCause = 11; TrapPc = "00000000"; TrapTval = "00000000" },
    @{ Name = "trap_ebreak"; Words = 2; TrapCause = 3; TrapPc = "00000000"; TrapTval = "00000000" },
    @{ Name = "trap_load_misaligned"; Words = 4; TrapCause = 4; TrapPc = "00000008"; TrapTval = "00000001" },
    @{ Name = "trap_store_misaligned"; Words = 4; TrapCause = 6; TrapPc = "00000008"; TrapTval = "00000001" },
    @{ Name = "trap_control_misaligned"; Words = 2; TrapCause = 0; TrapPc = "00000000"; TrapTval = "00000002" },
    @{ Name = "trap_csr_illegal"; Words = 3; TrapCause = 2; TrapPc = "00000004"; TrapTval = "30109073" },
    @{ Name = "trap_resume"; Words = 16; Retirements = 15; MaxCycles = 80; TrapCause = 11; TrapPc = "00000010"; TrapTval = "00000000" },
    @{ Name = "branch_misaligned_not_taken"; Words = 5; Retirements = 5 },
    @{ Name = "trap_jalr_misaligned"; Words = 3; TrapCause = 0; TrapPc = "00000004"; TrapTval = "00000002" },
    @{ Name = "csr_readonly_read"; Words = 4; Retirements = 4 }
)

& "$PSScriptRoot/build_tests.ps1"

New-Item -ItemType Directory -Force -Path "sim/build" | Out-Null

$simulator = "sim/build/tb_risc_processor.vvp"

iverilog -g2005 -Wall -Wno-timescale -s tb_risc_processor -o $simulator @rtl

if ($LASTEXITCODE -ne 0) {
    throw "Icarus Verilog compilation failed"
}

if (!(Test-Path -LiteralPath $simulator)) {
    throw "Compiled simulator output was not created: $simulator"
}

$tests += @{ Name = "fibonacci" }
$configs = @(
    @{ Name = "minimum"; Args = @() }
)
if (!$Quick) {
    $configs += @{ Name = "fixed"; Args = @("+IMEM_REQ_DELAY=3", "+IMEM_RSP_DELAY=4", "+DMEM_REQ_DELAY=7", "+DMEM_RSP_DELAY=8") }
    foreach ($seed in @(1, 17, 12345)) {
        $configs += @{ Name = "random-$seed"; Args = @("+IMEM_REQ_DELAY=2", "+DMEM_REQ_DELAY=5", "+RANDOM_DELAY=8", "+SEED=$seed") }
    }
}
$reference = @{}
$passed = 0
foreach ($config in $configs) {
    foreach ($test in $tests) {
        $name = $test.Name
        $arguments = @($simulator, "+TEST=$name", "+MAX_CYCLES=10000") + $config.Args
        if ($test.ContainsKey("Words")) {
            $program = "sim/build/programs/$name.hex"
            if ((Get-Content -LiteralPath $program).Count -ne $test.Words) {
                throw "$name generated unexpected program length"
            }
            $arguments += "+PROGRAM=$program", "+PROGRAM_WORDS=$($test.Words)"
        }
        if ($test.ContainsKey("Retirements")) {
            $arguments += "+EXPECTED_RETIREMENTS=$($test.Retirements)"
        }
        if ($test.ContainsKey("TrapCause")) {
            $arguments += "+EXPECTED_TRAP_CAUSE=$($test.TrapCause)",
                          "+EXPECTED_TRAP_PC=$($test.TrapPc)",
                          "+EXPECTED_TRAP_TVAL=$($test.TrapTval)"
        }
        if ($Trace) { $arguments += "+TRACE" }
        $result = @(& vvp @arguments)
        $exitCode = $LASTEXITCODE
        $log = "sim/build/$($config.Name)-$name.log"
        $result | Set-Content -LiteralPath $log
        if ($exitCode -ne 0 -or !($result -match "^TEST $name PASS$")) {
            $result | Write-Host
            throw "Simulation failed: $($config.Name) / $name"
        }
        $arch = ($result | Where-Object { $_ -like "ARCH *" }) -join "`n"
        if ($config.Name -eq "minimum") { $reference[$name] = $arch }
        elseif ($arch -cne $reference[$name]) {
            throw "Architectural trace differs: $($config.Name) / $name (see $log)"
        }
        if ($Trace) { $result | Write-Host }
        Write-Host "PASS $($config.Name) / $name"
        $passed++
    }
}

$machineTests = @(
    @{ Name="machine_interrupt_software"; Program="machine_interrupts" },
    @{ Name="machine_interrupt_timer"; Program="machine_interrupts" },
    @{ Name="machine_interrupt_external"; Program="machine_interrupts" },
    @{ Name="machine_interrupt_priority"; Program="machine_interrupts" },
    @{ Name="machine_interrupt_masking"; Program="machine_interrupt_masking" },
    @{ Name="machine_interrupt_branch"; Program="machine_branch_interrupt" },
    @{ Name="machine_interrupt_store"; Program="machine_memory_interrupt" },
    @{ Name="machine_interrupt_load"; Program="machine_memory_interrupt" },
    @{ Name="machine_counters"; Program="machine_counters"; TimingDependent=$true }
)
$machinePrograms = @($machineTests | ForEach-Object { $_.Program } | Select-Object -Unique)
& "$PSScriptRoot/build_tests.ps1" -Tests $machinePrograms
$machineSimulator = "sim/build/tb_machine_mode.vvp"
iverilog -g2005 -Wall -Wno-timescale -s tb_machine_mode -o $machineSimulator `
    @rtl sim/tb_machine_mode.v
if ($LASTEXITCODE -ne 0) { throw "Machine-mode milestone compilation failed" }
$machineReference = @{}
foreach ($config in $configs) {
    foreach ($test in $machineTests) {
        $name = $test.Name
        $programName = $test.Program
        $program = "sim/build/programs/$programName.hex"
        $words = (Get-Content -LiteralPath $program).Count
        $arguments = @($machineSimulator, "+TEST=$name", "+PROGRAM=$program",
                       "+PROGRAM_WORDS=$words", "+MAX_CYCLES=10000") + $config.Args
        $result = @(& vvp @arguments)
        $exitCode = $LASTEXITCODE
        $log = "sim/build/$($config.Name)-$name.log"
        $result | Set-Content -LiteralPath $log
        if ($exitCode -ne 0 -or !($result -match "^TEST $name PASS$")) {
            $result | Write-Host
            throw "Machine-mode milestone failed: $($config.Name) / $name"
        }
        $arch = ($result | Where-Object { $_ -like "ARCH *" }) -join "`n"
        if (!$test.ContainsKey("TimingDependent")) {
            if ($config.Name -eq "minimum") { $machineReference[$name] = $arch }
            elseif ($arch -cne $machineReference[$name]) {
                throw "Machine-mode architectural trace differs: $name (see $log)"
            }
        }
        Write-Host "PASS $($config.Name) / $name"
        $passed++
    }
}

$memoryTests = @(
    @{ Name="memory_wait_states"; Stores=2 },
    @{ Name="store_issued_once"; Stores=1 },
    @{ Name="fence_executable_ram"; Stores=3 },
    @{ Name="trap_load_access_fault"; Stores=0; TrapCause=5; TrapPc="00000004"; TrapTval="90000003" },
    @{ Name="trap_store_access_fault"; Stores=1; TrapCause=7; TrapPc="00000004"; TrapTval="90000000" },
    @{ Name="trap_instruction_access_fault"; Stores=0; TrapCause=1; TrapPc="90000000"; TrapTval="90000000" },
    @{ Name="trap_rom_write"; Stores=1; TrapCause=7; TrapPc="00000004"; TrapTval="00000000" }
)
& "$PSScriptRoot/build_tests.ps1" -Tests @($memoryTests | ForEach-Object { $_.Name })
$memorySimulator = "sim/build/tb_memory_milestone.vvp"
iverilog -g2005 -Wall -Wno-timescale -s tb_memory_milestone -o $memorySimulator @rtl sim/tb_memory_milestone.v
if ($LASTEXITCODE -ne 0) { throw "Memory milestone compilation failed" }
$memoryReference = @{}
foreach ($config in $configs) {
    foreach ($test in $memoryTests) {
        $name=$test.Name
        $program="sim/build/programs/$name.hex"
        $words=(Get-Content -LiteralPath $program).Count
        $arguments=@($memorySimulator, "+TEST=$name", "+PROGRAM=$program",
                     "+PROGRAM_WORDS=$words", "+EXPECTED_STORES=$($test.Stores)") + $config.Args
        if ($test.ContainsKey("TrapCause")) {
            $arguments += "+EXPECTED_TRAP_CAUSE=$($test.TrapCause)",
                          "+EXPECTED_TRAP_PC=$($test.TrapPc)", "+EXPECTED_TRAP_TVAL=$($test.TrapTval)"
        }
        $result=@(& vvp @arguments)
        $exitCode=$LASTEXITCODE
        $result | Set-Content "sim/build/$($config.Name)-$name.log"
        if ($exitCode -ne 0 -or !($result -match "^TEST $name PASS$")) {
            $result | Write-Host
            throw "Memory milestone failed: $($config.Name) / $name"
        }
        $arch=($result | Where-Object { $_ -like "ARCH *" }) -join "`n"
        if ($config.Name -eq "minimum") { $memoryReference[$name]=$arch }
        elseif ($arch -cne $memoryReference[$name]) { throw "Memory trace mismatch: $name" }
        Write-Host "PASS $($config.Name) / $name"
        $passed++
    }
}
foreach ($mode in @(1,2)) {
    $result=@(& vvp $memorySimulator "+TEST=memory_wait_states" "+PROGRAM=sim/build/programs/memory_wait_states.hex" "+PROGRAM_WORDS=13" "+EXPECTED_STORES=2" "+RESET_MODE=$mode" "+IMEM_RSP_DELAY=10" "+DMEM_RSP_DELAY=15")
    if ($LASTEXITCODE -ne 0) { $result | Write-Host; throw "Outstanding-transaction reset failed" }
    $result | Set-Content "sim/build/reset-$mode.log"
    Write-Host "PASS reset outstanding channel $mode"
    $passed++
}

foreach ($top in @("tb_fetch_discard", "tb_memory_adapter", "tb_ram_ports")) {
    $target="sim/build/$top.vvp"
    iverilog -g2005 -s $top -o $target @rtl "sim/$top.v"
    if ($LASTEXITCODE -ne 0) { throw "$top compilation failed" }
    $waits=if ($top -eq "tb_fetch_discard") { @(0,6) } else { @(0) }
    foreach ($wait in $waits) {
        & vvp $target "+REQUEST_WAIT=$wait"
        if ($LASTEXITCODE -ne 0) { throw "$top failed" }
        $passed++
    }
}
Write-Host "$passed simulations passed; retirement/trap traces agree across latency configurations."
