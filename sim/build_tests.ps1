param(
    [string[]]$Tests = @(
        "alu",
        "memory",
        "forwarding",
        "load_use",
        "branch_flush",
        "store_forward",
        "upper_immediate",
        "jumps",
        "jump_backward",
        "compare",
        "shifts",
        "branches_all",
        "subword_memory",
        "csr_mret",
        "fence_system",
        "trap_illegal",
        "trap_ecall",
        "trap_ebreak",
        "trap_load_misaligned",
        "trap_store_misaligned",
        "trap_control_misaligned",
        "trap_csr_illegal",
        "trap_resume",
        "branch_misaligned_not_taken",
        "trap_jalr_misaligned",
        "csr_readonly_read",
        "machine_interrupts",
        "machine_interrupt_masking",
        "machine_branch_interrupt",
        "machine_memory_interrupt",
        "machine_counters"
    )
)

$ErrorActionPreference = "Stop"

function Find-Tool {
    param(
        [string[]]$Names
    )

    foreach ($name in $Names) {
        $command = Get-Command $name -ErrorAction SilentlyContinue

        if ($null -ne $command) {
            return $command.Source
        }
    }

    throw "Required RISC-V tool was not found: $($Names -join ', ')"
}

$gcc = Find-Tool @(
    "riscv-none-elf-gcc",
    "riscv64-unknown-elf-gcc",
    "riscv32-unknown-elf-gcc"
)

$objcopy = Find-Tool @(
    "riscv-none-elf-objcopy",
    "riscv64-unknown-elf-objcopy",
    "riscv32-unknown-elf-objcopy"
)

$objdump = Find-Tool @(
    "riscv-none-elf-objdump",
    "riscv64-unknown-elf-objdump",
    "riscv32-unknown-elf-objdump"
)

$repoRoot = Split-Path -Parent $PSScriptRoot
$sourceDirectory = Join-Path $repoRoot "tests\asm"
$linkerScript = Join-Path $repoRoot "tests\link.ld"
$outputDirectory = Join-Path $repoRoot "sim\build\programs"

New-Item `
    -ItemType Directory `
    -Force `
    -Path $outputDirectory |
    Out-Null

foreach ($testName in $Tests) {
    $sourcePath = Join-Path $sourceDirectory "$testName.S"
    $elfPath = Join-Path $outputDirectory "$testName.elf"
    $binaryPath = Join-Path $outputDirectory "$testName.bin"
    $hexPath = Join-Path $outputDirectory "$testName.hex"
    $listingPath = Join-Path $outputDirectory "$testName.lst"

    if (!(Test-Path -LiteralPath $sourcePath)) {
        throw "Assembly source does not exist: $sourcePath"
    }

    Write-Host "Assembling $testName"

    & $gcc `
        -march=rv32i_zicsr_zifencei `
        -mabi=ilp32 `
        -nostdlib `
        -nostartfiles `
        "-Wl,--build-id=none" `
        "-Wl,--no-relax" `
        "-Wl,-T,$linkerScript" `
        -o $elfPath `
        $sourcePath

    if ($LASTEXITCODE -ne 0) {
        throw "Failed to build $testName"
    }

    & $objdump `
        -d `
        -M no-aliases `
        $elfPath |
        Set-Content -LiteralPath $listingPath

    if ($LASTEXITCODE -ne 0) {
        throw "Failed to disassemble $testName"
    }

    & $objcopy `
        -O binary `
        $elfPath `
        $binaryPath

    if ($LASTEXITCODE -ne 0) {
        throw "Failed to extract $testName binary"
    }

    $bytes = [System.IO.File]::ReadAllBytes($binaryPath)

    if (($bytes.Length % 4) -ne 0) {
        throw "$testName binary is not a multiple of four bytes"
    }

    $hexLines = [System.Collections.Generic.List[string]]::new()

    for ($index = 0; $index -lt $bytes.Length; $index += 4) {
        [uint32]$word =
            [uint32]$bytes[$index] `
            -bor ([uint32]$bytes[$index + 1] -shl 8) `
            -bor ([uint32]$bytes[$index + 2] -shl 16) `
            -bor ([uint32]$bytes[$index + 3] -shl 24)

        $hexLines.Add(("{0:x8}" -f $word))
    }

    [System.IO.File]::WriteAllLines(
        $hexPath,
        $hexLines
    )

    Write-Host "Generated $hexPath"
}
