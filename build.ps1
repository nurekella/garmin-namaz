# Build script for Connect IQ namaz app.
# Usage:
#   .\build.ps1                 # debug build for epix2
#   .\build.ps1 -Device fenix7  # build for another device
#   .\build.ps1 -Release        # release .iq for store
#   .\build.ps1 -Test           # build unit-test prg

param(
    [string]$Device = "epix2",
    [switch]$Release,
    [switch]$Test
)

$ErrorActionPreference = "Stop"

# --- Resolve Java ---
$jdkRoot = "C:\Program Files\Microsoft\jdk-21.0.10.7-hotspot"
if (-not (Test-Path "$jdkRoot\bin\java.exe")) {
    # fallback: try any JDK under Program Files\Microsoft
    $jdkRoot = (Get-ChildItem "C:\Program Files\Microsoft" -Filter "jdk-*" -Directory -ErrorAction SilentlyContinue |
                Sort-Object Name -Descending | Select-Object -First 1).FullName
}
if (-not $jdkRoot -or -not (Test-Path "$jdkRoot\bin\java.exe")) {
    throw "Java JDK not found. Install with: winget install Microsoft.OpenJDK.21"
}
$env:JAVA_HOME = $jdkRoot
$env:PATH = "$jdkRoot\bin;$env:PATH"

# --- Resolve Connect IQ SDK ---
$ciqRoot = "$env:APPDATA\Garmin\ConnectIQ"
$currentSdkCfg = Join-Path $ciqRoot "current-sdk.cfg"
if (Test-Path $currentSdkCfg) {
    $sdkPath = (Get-Content $currentSdkCfg -Raw).Trim()
} else {
    $sdkPath = (Get-ChildItem "$ciqRoot\Sdks" -Directory -ErrorAction SilentlyContinue |
                Sort-Object Name -Descending | Select-Object -First 1).FullName
}
if (-not $sdkPath -or -not (Test-Path $sdkPath)) {
    throw "Connect IQ SDK not found under $ciqRoot\Sdks"
}
$sdkBin = Join-Path $sdkPath "bin"
$monkeyc = Join-Path $sdkBin "monkeyc.bat"
if (-not (Test-Path $monkeyc)) {
    throw "monkeyc.bat not found at $monkeyc"
}

# --- Resolve dev key ---
$devKey = Join-Path $PSScriptRoot "developer_key"
if (-not (Test-Path $devKey)) {
    throw "developer_key not found at $devKey. Generate with openssl (see README)."
}

# --- Build ---
New-Item -ItemType Directory -Force -Path "$PSScriptRoot\bin" | Out-Null

if ($Test) {
    $output = "bin/namaz_test.prg"
    $args = @("-d", $Device, "-f", "monkey.jungle", "-o", $output, "-y", "developer_key", "--unit-test", "-w")
    Write-Host "Building unit-test prg for $Device ..." -ForegroundColor Cyan
} elseif ($Release) {
    $output = "bin/namaz.iq"
    $args = @("-e", "-d", $Device, "-f", "monkey.jungle", "-o", $output, "-y", "developer_key", "-r", "-w")
    Write-Host "Building release .iq for $Device ..." -ForegroundColor Cyan
} else {
    $output = "bin/namaz.prg"
    $args = @("-d", $Device, "-f", "monkey.jungle", "-o", $output, "-y", "developer_key", "-w")
    Write-Host "Building debug prg for $Device ..." -ForegroundColor Cyan
}

Write-Host "JAVA_HOME = $env:JAVA_HOME"
Write-Host "SDK       = $sdkPath"
Write-Host ""

Push-Location $PSScriptRoot
try {
    & $monkeyc @args
    if ($LASTEXITCODE -ne 0) {
        throw "monkeyc failed with exit code $LASTEXITCODE"
    }
    $size = (Get-Item $output).Length
    Write-Host ""
    Write-Host "OK -> $output  ($size bytes)" -ForegroundColor Green
} finally {
    Pop-Location
}
