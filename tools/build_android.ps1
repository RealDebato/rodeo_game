<#
.SYNOPSIS
    Exports the Android build headlessly and (optionally) installs and launches it on a USB device.

.DESCRIPTION
    Debug (default): preset "Android" -> build\android\laser_detumbling-debug.apk, debug-signed,
                     installed and launched on the connected phone.
    -Release:        preset "Android Release APK" -> build\android\laser_detumbling-release.apk,
                     signed with the release key, for sharing directly (not installed automatically).
    -Release -Aab:   preset "Android Release AAB" -> build\android\laser_detumbling-release.aab,
                     Gradle build signed with the release (upload) key, for Google Play.

    Release signing reads %USERPROFILE%\.laser-detumbling\release.properties (created by
    tools\create_release_keystore.ps1) and hands the key to Godot via environment variables, so
    no secret is stored in the project. Requires tools\setup_windows.ps1 (-WithGradleBuildTools
    for -Aab).

.PARAMETER Release
    Build a release instead of a debug build.

.PARAMETER Aab
    With -Release: build the Android App Bundle for Google Play (Gradle build).

.PARAMETER NoInstall
    Debug only: export, but do not install on the phone.

.PARAMETER Logcat
    Debug only: after launching, stream the Godot log from the device (Ctrl+C to stop).

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File tools\build_android.ps1 -Release -Aab
#>
[CmdletBinding()]
param(
    [switch]$Release,
    [switch]$Aab,
    [switch]$NoInstall,
    [switch]$Logcat
)

$ErrorActionPreference = 'Stop'

$ProjectRoot    = Split-Path -Parent $PSScriptRoot
$PackageName    = 'com.rodeogames.laserdetumbling'   # keep in sync with export_presets.cfg
$BuildDir       = Join-Path $ProjectRoot 'build\android'
$KeyProperties  = Join-Path $env:USERPROFILE '.laser-detumbling\release.properties'

if ($Aab -and -not $Release) { throw '-Aab requires -Release (Google Play only accepts release bundles).' }

if (-not $Release) {
    $Preset = 'Android'; $Output = Join-Path $BuildDir 'laser_detumbling-debug.apk'
} elseif ($Aab) {
    $Preset = 'Android Release AAB'; $Output = Join-Path $BuildDir 'laser_detumbling-release.aab'
} else {
    $Preset = 'Android Release APK'; $Output = Join-Path $BuildDir 'laser_detumbling-release.apk'
}

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

function Read-KeyProperties([string]$Path) {
    if (-not (Test-Path $Path)) {
        throw "No release key found ($Path). Run tools\create_release_keystore.ps1 first."
    }
    $values = @{}
    foreach ($line in Get-Content $Path) {
        $i = $line.IndexOf('=')
        if ($i -gt 0) { $values[$line.Substring(0, $i).Trim()] = $line.Substring($i + 1).Trim() }
    }
    foreach ($key in 'keystore', 'alias', 'password') {
        if (-not $values[$key]) { throw "$Path is missing '$key'." }
    }
    return $values
}

foreach ($name in 'JAVA_HOME', 'ANDROID_HOME') {
    if (-not [Environment]::GetEnvironmentVariable($name)) {
        Set-Item "env:$name" ([Environment]::GetEnvironmentVariable($name, 'User'))
    }
}
$godot = Resolve-Tool 'GODOT' 'godot' $null
$adb = Resolve-Tool 'ADB' 'adb' (Join-Path "$env:ANDROID_HOME" 'platform-tools\adb.exe')

# --- Signing --------------------------------------------------------------------------------------
if ($Release) {
    $key = Read-KeyProperties $KeyProperties
    # Godot reads these instead of the (empty) keystore fields of the preset.
    $env:GODOT_ANDROID_KEYSTORE_RELEASE_PATH = $key['keystore']
    $env:GODOT_ANDROID_KEYSTORE_RELEASE_USER = $key['alias']
    $env:GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD = $key['password']
}

# --- Export ---------------------------------------------------------------------------------------
New-Item -ItemType Directory -Force $BuildDir | Out-Null
$gdignore = Join-Path $ProjectRoot 'build\.gdignore'
if (-not (Test-Path $gdignore)) { New-Item -ItemType File $gdignore | Out-Null }
if (Test-Path $Output) { Remove-Item $Output -Force }

Write-Host "==> Exporting '$Preset' with $godot" -ForegroundColor Cyan
# --import makes sure the .godot import cache exists (first export on a fresh clone).
Invoke-Native { & $godot --headless --path $ProjectRoot --import } 'Godot import'
$exportArgs = @('--headless', '--path', $ProjectRoot)
if ($Aab -and -not (Test-Path (Join-Path $ProjectRoot 'android\build'))) {
    Write-Host '    installing the Android Gradle build template (first AAB build)' -ForegroundColor Cyan
    $exportArgs += '--install-android-build-template'
}
$exportArgs += @($(if ($Release) { '--export-release' } else { '--export-debug' }), $Preset, $Output)
try {
    Invoke-Native { & $godot @exportArgs } 'Godot export'
} finally {
    Remove-Item env:GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD -ErrorAction SilentlyContinue
}
if (-not (Test-Path $Output)) { throw "Export reported success but $Output was not created." }
Write-Host ("    {0} ({1:N1} MB)" -f $Output, ((Get-Item $Output).Length / 1MB)) -ForegroundColor Green

if ($Release) {
    Write-Host '    Release builds are not installed automatically (different signature than the debug app).'
    return
}
if ($NoInstall) { return }

# --- Install & launch (debug) ---------------------------------------------------------------------
# Start the adb server in its own hidden console. If the first adb call spawns the server instead,
# the long-lived server inherits this script's stdout/stderr handles, and any caller that captures
# our output (e.g. `$x = build_android.ps1 | Out-String`) waits forever for end-of-output.
# Do NOT use `Start-Process -Wait`: in Windows PowerShell it also waits for child processes,
# i.e. for the adb server, which never exits. WaitForExit() waits for `adb start-server` only.
$adbStart = Start-Process -FilePath $adb -ArgumentList 'start-server' -WindowStyle Hidden -PassThru
if (-not $adbStart.WaitForExit(30000)) { throw 'adb start-server did not finish within 30 s.' }

$devices = @(& $adb devices | Select-Object -Skip 1 | Where-Object { $_ -match '\tdevice$' })
if ($devices.Count -eq 0) {
    $unauthorized = @(& $adb devices | Where-Object { $_ -match '\tunauthorized$' })
    if ($unauthorized.Count -gt 0) { throw 'Device is unauthorized: unlock the phone and accept the USB debugging prompt.' }
    throw ("No Android device found by adb. Enable Developer options + USB debugging on the phone " +
        "(Phone Link is not needed), replug the cable and accept the prompt on the phone. " +
        "The APK was exported to $Output. See docs/ANDROID_DEPLOYMENT.md#phone-not-listed-by-adb")
}
if ($devices.Count -gt 1) { throw "Multiple devices connected; set ANDROID_SERIAL to choose one:`n$($devices -join "`n")" }

Write-Host "==> Installing on $($devices[0] -replace '\t.*','')" -ForegroundColor Cyan
Invoke-Native { & $adb install -r $Output } 'adb install'

Write-Host '==> Launching' -ForegroundColor Cyan
Invoke-Native { & $adb shell monkey -p $PackageName -c android.intent.category.LAUNCHER 1 | Out-Null } 'App launch'

if ($Logcat) {
    Write-Host '==> Streaming Godot log (Ctrl+C to stop)' -ForegroundColor Cyan
    & $adb logcat -c
    & $adb logcat -s godot:V GodotApp:V
}
