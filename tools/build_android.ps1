<#
.SYNOPSIS
    Exports the Android APK headlessly and (optionally) installs and launches it on a USB device.

.DESCRIPTION
    Uses the "Android" preset from export_presets.cfg. Requires tools\setup_windows.ps1 to have
    been run (Godot, JDK 17, Android SDK, export templates, editor settings).

.PARAMETER Release
    Export a release build instead of a debug build. Requires a release keystore configured in
    the Godot export dialog (Project > Export > Android > Keystore).

.PARAMETER NoInstall
    Only export the APK, do not install it.

.PARAMETER Logcat
    After launching, stream the Godot log from the device (Ctrl+C to stop).

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File tools\build_android.ps1 -Logcat
#>
[CmdletBinding()]
param(
    [switch]$Release,
    [switch]$NoInstall,
    [switch]$Logcat
)

$ErrorActionPreference = 'Stop'

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$PresetName  = 'Android'
$PackageName = 'com.rodeogames.laserdetumbling'   # keep in sync with export_presets.cfg
$BuildDir    = Join-Path $ProjectRoot 'build\android'
$Variant     = if ($Release) { 'release' } else { 'debug' }
$ApkPath     = Join-Path $BuildDir "laser_detumbling-$Variant.apk"

function Resolve-Tool([string]$EnvName, [string]$CommandName, [string]$Fallback) {
    $fromEnv = [Environment]::GetEnvironmentVariable($EnvName)
    if (-not $fromEnv) { $fromEnv = [Environment]::GetEnvironmentVariable($EnvName, 'User') }
    if ($fromEnv -and (Test-Path $fromEnv)) { return $fromEnv }
    $cmd = Get-Command $CommandName -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    if ($Fallback -and (Test-Path $Fallback)) { return $Fallback }
    throw "$CommandName not found. Run tools\setup_windows.ps1 first."
}

function Invoke-Native([scriptblock]$Command, [string]$What) {
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try { & $Command } finally { $ErrorActionPreference = $previous }
    if ($LASTEXITCODE -ne 0) { throw "$What failed with exit code $LASTEXITCODE" }
}

$godot = Resolve-Tool 'GODOT' 'godot' $null
$sdk = [Environment]::GetEnvironmentVariable('ANDROID_HOME')
if (-not $sdk) { $sdk = [Environment]::GetEnvironmentVariable('ANDROID_HOME', 'User') }
$adb = Resolve-Tool 'ADB' 'adb' (Join-Path "$sdk" 'platform-tools\adb.exe')

# --- Export -------------------------------------------------------------------------------------------
New-Item -ItemType Directory -Force $BuildDir | Out-Null
# Keep Godot from scanning/importing the build output.
$gdignore = Join-Path $ProjectRoot 'build\.gdignore'
if (-not (Test-Path $gdignore)) { New-Item -ItemType File $gdignore | Out-Null }
if (Test-Path $ApkPath) { Remove-Item $ApkPath -Force }

Write-Host "==> Exporting $Variant APK with $godot" -ForegroundColor Cyan
# --import makes sure the .godot import cache exists (first export on a fresh clone).
Invoke-Native { & $godot --headless --path $ProjectRoot --import } 'Godot import'
Invoke-Native { & $godot --headless --path $ProjectRoot "--export-$Variant" $PresetName $ApkPath } 'Godot export'
if (-not (Test-Path $ApkPath)) { throw "Export reported success but $ApkPath was not created." }
Write-Host ("    APK: {0} ({1:N1} MB)" -f $ApkPath, ((Get-Item $ApkPath).Length / 1MB)) -ForegroundColor Green

if ($NoInstall) { return }

# --- Install & launch -----------------------------------------------------------------------------------
# Start the adb server in its own hidden console. If the first adb call spawns the server instead,
# the long-lived server inherits this script's stdout/stderr handles, and any caller that captures
# our output (e.g. `$x = build_android.ps1 | Out-String`) waits forever for end-of-output.
Start-Process -FilePath $adb -ArgumentList 'start-server' -WindowStyle Hidden -Wait

$devices =@(& $adb devices | Select-Object -Skip 1 | Where-Object { $_ -match '\tdevice$' })
if ($devices.Count -eq 0) {
    $unauthorized = @(& $adb devices | Where-Object { $_ -match '\tunauthorized$' })
    if ($unauthorized.Count -gt 0) { throw 'Device is unauthorized: unlock the phone and accept the USB debugging prompt.' }
    throw ("No Android device found by adb. Enable Developer options + USB debugging on the phone " +
        "(Phone Link is not needed), replug the cable and accept the prompt on the phone. " +
        "The APK was exported to $ApkPath. See docs/ANDROID_DEPLOYMENT.md#phone-not-listed-by-adb")
}
if ($devices.Count -gt 1) { throw "Multiple devices connected; set ANDROID_SERIAL to choose one:`n$($devices -join "`n")" }

Write-Host "==> Installing on $($devices[0] -replace '\t.*','')" -ForegroundColor Cyan
Invoke-Native { & $adb install -r $ApkPath } 'adb install'

Write-Host '==> Launching' -ForegroundColor Cyan
Invoke-Native { & $adb shell monkey -p $PackageName -c android.intent.category.LAUNCHER 1 | Out-Null } 'App launch'

if ($Logcat) {
    Write-Host '==> Streaming Godot log (Ctrl+C to stop)' -ForegroundColor Cyan
    & $adb logcat -c
    & $adb logcat -s godot:V GodotApp:V
}
