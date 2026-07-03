$ErrorActionPreference = "Stop"

$rtl = @(
    "rtl/pc.v",
    "rtl/instruction_memory.v",
    "rtl/control_unit.v",
    "rtl/register_file.v",
    "rtl/alu.v",
    "rtl/data_memory.v",
    "rtl/risc_processor.v",
    "sim/tb_risc_processor.v"
)

$tests = @(
    @{ Name = "alu"; Words = 10 },
    @{ Name = "memory"; Words = 7 },
    @{ Name = "forwarding"; Words = 7 },
    @{ Name = "load_use"; Words = 6 },
    @{ Name = "branch_flush"; Words = 8 },
    @{ Name = "store_forward"; Words = 8 }
)

New-Item -ItemType Directory -Force -Path "sim/build" | Out-Null

iverilog -g2012 -o "sim/build/tb_risc_processor.vvp" @rtl

$failures = 0
foreach ($test in $tests) {
    $name = $test.Name
    $words = $test.Words
    Write-Host "===== $name ====="
    vvp "sim/build/tb_risc_processor.vvp" "+TEST=$name" "+PROGRAM=tests/$name.hex" "+PROGRAM_WORDS=$words" "+MAX_CYCLES=40"
    if ($LASTEXITCODE -ne 0) {
        $failures += 1
    }
}

if ($failures -ne 0) {
    throw "$failures simulation test(s) failed"
}

Write-Host "All self-checking simulation tests passed."
