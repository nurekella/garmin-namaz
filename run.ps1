# Launch Connect IQ simulator and load the built prg.
# Usage:
#   .\run.ps1                 # default: epix2 + bin/namaz.prg
#   .\run.ps1 -Device fenix7
#   .\run.ps1 -Test           # load namaz_test.prg with -t

param(
    [string]$Device = "epix2",
    [switch]$Test
)

$ErrorActionPreference = "Stop"

# --- Java ---
$jdkRoot = "C:\Program Files\Microsoft\jdk-21.0.10.7-hotspot"
if (-not (Test-Path "$jdkRoot\bin\java.exe")) {
    $jdkRoot = (Get-ChildItem "C:\Program Files\Microsoft" -Filter "jdk-*" -Directory -ErrorAction SilentlyContinue |
                Sort-Object Name -Descending | Select-Object -First 1).FullName
}
if (-not $jdkRoot) { throw "Java JDK not found." }
$env:JAVA_HOME = $jdkRoot
$env:PATH = "$jdkRoot\bin;$env:PATH"

# --- SDK ---
$ciqRoot = "$env:APPDATA\Garmin\ConnectIQ"
$currentSdkCfg = Join-Path $ciqRoot "current-sdk.cfg"
$sdkPath = if (Test-Path $currentSdkCfg) {
    (Get-Content $currentSdkCfg -Raw).Trim()
} else {
    (Get-ChildItem "$ciqRoot\Sdks" -Directory | Sort-Object Name -Descending | Select-Object -First 1).FullName
}
$sdkBin   = Join-Path $sdkPath "bin"
$connectiq = Join-Path $sdkBin "connectiq.bat"
$monkeydo  = Join-Path $sdkBin "monkeydo.bat"

# --- Pick prg ---
$prg = if ($Test) { "bin\namaz_test.prg" } else { "bin\namaz.prg" }
if (-not (Test-Path (Join-Path $PSScriptRoot $prg))) {
    throw "$prg not found. Run .\build.ps1 first."
}

# --- Start simulator if not running ---
if (-not (Get-Process -Name "simulator" -ErrorAction SilentlyContinue)) {
    Write-Host "Starting Connect IQ simulator..." -ForegroundColor Cyan
    Start-Process $connectiq -WindowStyle Normal
    Start-Sleep -Seconds 4
} else {
    Write-Host "Simulator already running." -ForegroundColor Yellow
}

Write-Host "Loading $prg on $Device ..." -ForegroundColor Cyan
Push-Location $PSScriptRoot
try {
    if ($Test) {
        & $monkeydo $prg $Device -t
    } else {
        & $monkeydo $prg $Device
    }
} finally {
    Pop-Location
}
