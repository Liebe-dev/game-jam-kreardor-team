param(
    [Parameter(Mandatory = $true)][string]$GodotPath,
    [Parameter(Mandatory = $true)][string]$TestDataDir,
    [string]$ProjectPath = (Split-Path -Parent $PSScriptRoot),
    [switch]$Import
)

$ErrorActionPreference = 'Stop'
$engine = (Resolve-Path -LiteralPath $GodotPath).Path
$project = (Resolve-Path -LiteralPath $ProjectPath).Path
$scratch = [System.IO.Path]::GetFullPath($TestDataDir)
New-Item -ItemType Directory -Path $scratch -Force | Out-Null
$previousTestDataDir = $env:AUTOCHESSTO_TEST_DATA_DIR

try {
    $env:AUTOCHESSTO_TEST_DATA_DIR = $scratch
    if ($Import -or -not (Test-Path -LiteralPath (Join-Path $project '.godot\global_script_class_cache.cfg'))) {
        $importLog = Join-Path $scratch 'import.log'
        & $engine --headless --path $project --import --log-file (Join-Path $scratch 'import-engine.log') *> $importLog
        if ($LASTEXITCODE -ne 0 -or (Select-String -LiteralPath $importLog -Pattern '^(SCRIPT ERROR:|ERROR:)' -Quiet)) {
            Get-Content -LiteralPath $importLog
            throw 'Godot import failed.'
        }
    }
    $log = Join-Path $scratch 'operations.log'
    & $engine --headless --path $project --script res://tests/operations_regression.gd --log-file (Join-Path $scratch 'engine.log') *> $log
    $engineExitCode = $LASTEXITCODE
    $summary = Select-String -LiteralPath $log -Pattern '^RESULT '
    $errors = Select-String -LiteralPath $log -Pattern '^(SCRIPT ERROR:|ERROR:|FAIL |TEST TIMEOUT)'
    if ($engineExitCode -ne 0 -or $errors -or -not $summary) {
        Get-Content -LiteralPath $log
        throw "Operational regression failed (Godot exit $engineExitCode)."
    }
    $summary.Line | Write-Output
    Write-Output "Log: $log"
} finally {
    $env:AUTOCHESSTO_TEST_DATA_DIR = $previousTestDataDir
}
