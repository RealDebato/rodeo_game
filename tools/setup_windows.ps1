<#
.SYNOPSIS
    Installs and configures the Laser De-Tumbling toolchain on Windows. No admin rights required.

.DESCRIPTION
    Installs or verifies, in this order:
      1. Godot 4.7.2 (winget, portable)           + a `godot` command shim and the GODOT env var
      2. Eclipse Temurin OpenJDK 17 (zip, per user) + JAVA_HOME
      3. Android SDK command-line tools, platform-tools, build-tools 35.0.1, platform android-35
                                                     + ANDROID_HOME and platform-tools on PATH
      4. Godot export templates 4.7.2
      5. Godot editor settings: Java/Android SDK paths, VS Code as external script editor
      6. VS Code extension geequlim.godot-tools

    Each step is skipped if the component is already present, so the script is safe to re-run.
    Environment variables are written to the *user* environment; open a new terminal afterwards.

.PARAMETER AcceptAndroidLicenses
    Accept the Android SDK licenses non-interactively. Only use this if you have read and accepted
    https://developer.android.com/studio/terms. Without it, sdkmanager asks you to accept them.

.PARAMETER WithGradleBuildTools
    Also install Android 36, build-tools 36.1.0 and NDK 29.0.14206865 (what Godot 4.7.2's Gradle
    template expects). Needed for Gradle builds, i.e. the AAB for Google Play. Not needed for the
    standard APK export used during development.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File tools\setup_windows.ps1
#>
[CmdletBinding()]
param(
    [switch]$AcceptAndroidLicenses,
    [switch]$WithGradleBuildTools,
    [switch]$SkipAndroidSdk,
    [switch]$SkipExportTemplates,
    [switch]$SkipVSCode
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

# --- Pinned versions (update together with docs/SETUP_WINDOWS.md and CLAUDE.md) -------------------
$GodotVersion       = '4.7.2'
$GodotWingetId      = 'GodotEngine.GodotEngine'
$JdkMajor           = 17
$CmdlineToolsZip    = 'commandlinetools-win-15859902_latest.zip'
$CmdlineToolsSha256 = '90ae805d20434428bffcb699c290860f19bb5f66a67e6b330067e3de801fb04a'
$SdkPackages        = @('platform-tools', 'build-tools/35.0.1', 'platforms/android-35')
# Versions required by Godot 4.7.2's Gradle template (android_source.zip: config.gradle).
$GradlePackages     = @('platforms/android-36', 'build-tools/36.1.0', 'ndk/29.0.14206865')

# --- Locations --------------------------------------------------------------------------------------
$JdkRoot      = Join-Path $env:LOCALAPPDATA 'Programs\Temurin'
$ShimDir      = Join-Path $env:LOCALAPPDATA 'Programs\GodotShim'
$SdkRoot      = if ($env:ANDROID_HOME) { $env:ANDROID_HOME } else { Join-Path $env:LOCALAPPDATA 'Android\Sdk' }
$GodotData    = Join-Path $env:APPDATA 'Godot'
$TemplatesDir = Join-Path $GodotData "export_templates\$GodotVersion.stable"
$DownloadDir  = Join-Path $env:TEMP 'laser-detumbling-setup'
$Curl         = Join-Path $env:SystemRoot 'System32\curl.exe'
$Tar          = Join-Path $env:SystemRoot 'System32\tar.exe'

New-Item -ItemType Directory -Force $DownloadDir | Out-Null

# --- Helpers ----------------------------------------------------------------------------------------
function Write-Step([string]$Message) { Write-Host "`n==> $Message" -ForegroundColor Cyan }
function Write-Ok([string]$Message)   { Write-Host "    OK  $Message" -ForegroundColor Green }

function Set-UserEnv([string]$Name, [string]$Value) {
    [Environment]::SetEnvironmentVariable($Name, $Value, 'User')
    Set-Item -Path "env:$Name" -Value $Value
}

function Add-UserPath([string]$Dir) {
    $current = [Environment]::GetEnvironmentVariable('Path', 'User')
    $parts = @($current -split ';' | Where-Object { $_ })
    if ($parts -notcontains $Dir) {
        [Environment]::SetEnvironmentVariable('Path', (($parts + $Dir) -join ';'), 'User')
    }
    if (($env:Path -split ';') -notcontains $Dir) { $env:Path = "$env:Path;$Dir" }
}

# Runs a native command without PowerShell 5.1 turning stderr output into terminating errors.
function Invoke-Native([scriptblock]$Command, [string]$What) {
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try { & $Command } finally { $ErrorActionPreference = $previous }
    if ($LASTEXITCODE -ne 0) { throw "$What failed with exit code $LASTEXITCODE" }
}

function Get-Download([string]$Url, [string]$Destination) {
    if (Test-Path $Destination) { return }
    Write-Host "    downloading $Url"
    Invoke-Native { & $Curl -L --fail --silent --show-error -o "$Destination.part" $Url } "Download of $Url"
    Move-Item "$Destination.part" $Destination -Force
}

function Find-GodotExe {
    $pkg = Get-ChildItem (Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Packages') -Directory `
        -Filter "$GodotWingetId`_*" -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $pkg) { return $null }
    Get-ChildItem $pkg.FullName -File -Filter "Godot_v$GodotVersion-stable_win64*.exe" |
        Sort-Object Name | Select-Object -First 1   # GUI exe sorts before *_console.exe
}

# Upserts `key = value` lines in Godot's editor_settings-<major.minor>.tres ([resource] is its last section).
function Set-GodotEditorSettings([hashtable]$Settings) {
    $minor = ($GodotVersion -split '\.')[0..1] -join '.'
    $file = Join-Path $GodotData "editor_settings-$minor.tres"
    if (-not (Test-Path $file)) {
        New-Item -ItemType Directory -Force $GodotData | Out-Null
        Set-Content -Path $file -Encoding ASCII -Value "[gd_resource type=`"EditorSettings`" format=3]`n`n[resource]"
    }
    $lines = [System.Collections.Generic.List[string]]@(Get-Content $file)
    foreach ($key in $Settings.Keys) {
        $line = "$key = $($Settings[$key])"
        $pattern = "^$([regex]::Escape($key))\s*="
        $index = $lines.FindIndex([Predicate[string]]{ param($l) $l -match $pattern })
        if ($index -ge 0) { $lines[$index] = $line } else { $lines.Add($line) }
    }
    # Godot writes UTF-8 without BOM; WriteAllLines does the same.
    [System.IO.File]::WriteAllLines($file, $lines)
    return $file
}

function ConvertTo-GodotPath([string]$Path) { '"' + ($Path -replace '\\', '/') + '"' }

# --- 1. Godot ---------------------------------------------------------------------------------------
Write-Step "Godot $GodotVersion"
$godotExe = Find-GodotExe
if (-not $godotExe) {
    Invoke-Native {
        winget install --id $GodotWingetId --version $GodotVersion --exact --silent `
            --accept-package-agreements --accept-source-agreements --disable-interactivity
    } 'winget install Godot'
    $godotExe = Find-GodotExe
    if (-not $godotExe) { throw 'Godot was installed by winget but the executable was not found.' }
}
$godotConsoleExe = Join-Path $godotExe.DirectoryName ($godotExe.BaseName + '_console.exe')
New-Item -ItemType Directory -Force $ShimDir | Out-Null
Set-Content -Path (Join-Path $ShimDir 'godot.cmd') -Encoding ASCII -Value "@`"$godotConsoleExe`" %*"
Add-UserPath $ShimDir
Set-UserEnv 'GODOT' $godotConsoleExe
Write-Ok "$($godotExe.FullName)"
Write-Ok "command shim: $ShimDir\godot.cmd   (GODOT=$godotConsoleExe)"

# --- 2. OpenJDK 17 ----------------------------------------------------------------------------------
Write-Step "Eclipse Temurin OpenJDK $JdkMajor"
$jdkHome = Get-ChildItem $JdkRoot -Directory -Filter "jdk-$JdkMajor*" -ErrorAction SilentlyContinue |
    Sort-Object Name -Descending | Select-Object -First 1
if (-not $jdkHome) {
    $zip = Join-Path $DownloadDir "temurin-$JdkMajor.zip"
    Get-Download "https://api.adoptium.net/v3/binary/latest/$JdkMajor/ga/windows/x64/jdk/hotspot/normal/eclipse" $zip
    New-Item -ItemType Directory -Force $JdkRoot | Out-Null
    Expand-Archive -Path $zip -DestinationPath $JdkRoot -Force
    $jdkHome = Get-ChildItem $JdkRoot -Directory -Filter "jdk-$JdkMajor*" | Sort-Object Name -Descending | Select-Object -First 1
}
Set-UserEnv 'JAVA_HOME' $jdkHome.FullName
$javaVersion = (Get-Content (Join-Path $jdkHome.FullName 'release') | Select-String '^JAVA_VERSION=').Line
Write-Ok "$($jdkHome.FullName)  ($javaVersion)"

# --- 3. Android SDK ---------------------------------------------------------------------------------
if (-not $SkipAndroidSdk) {
    Write-Step 'Android SDK'
    if (-not (Test-Path (Join-Path $SdkRoot 'cmdline-tools\latest\bin\android.exe'))) {
        $zip = Join-Path $DownloadDir $CmdlineToolsZip
        Get-Download "https://dl.google.com/android/repository/$CmdlineToolsZip" $zip
        $hash = (Get-FileHash $zip -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($hash -ne $CmdlineToolsSha256) {
            Remove-Item $zip -Force
            throw "Checksum mismatch for $CmdlineToolsZip (got $hash)."
        }
        $extract = Join-Path $DownloadDir 'cmdline-tools-extract'
        Remove-Item $extract -Recurse -Force -ErrorAction SilentlyContinue
        Expand-Archive -Path $zip -DestinationPath $extract
        New-Item -ItemType Directory -Force (Join-Path $SdkRoot 'cmdline-tools') | Out-Null
        Move-Item (Join-Path $extract 'cmdline-tools') (Join-Path $SdkRoot 'cmdline-tools\latest')
    }
    Set-UserEnv 'ANDROID_HOME' $SdkRoot

    $packages = $SdkPackages
    if ($WithGradleBuildTools) { $packages = $packages + $GradlePackages }
    # A package counts as installed when its folder exists, e.g. build-tools/35.0.1 -> <sdk>\build-tools\35.0.1
    $missing = @($packages | Where-Object { -not (Test-Path (Join-Path $SdkRoot ($_ -replace '/', '\'))) })

    if ($missing.Count -gt 0) {
        if (-not $AcceptAndroidLicenses) {
            Write-Host '    Installing Android SDK packages requires accepting the Android SDK license:'
            Write-Host '    https://developer.android.com/studio/terms'
            $answer = Read-Host '    Do you accept the Android SDK license terms? (y/N)'
            if ($answer -notmatch '^(y|yes)$') { throw 'Android SDK license not accepted; aborting.' }
        }
        # Since cmdline-tools 20 (2026) `sdkmanager` is deprecated; `android sdk install` replaces it.
        # Package names use '/' (build-tools/35.0.1). --no-metrics disables Google usage telemetry.
        # Unknown package names are silently ignored with exit code 0, so we verify the folders below.
        $androidCli = Join-Path $SdkRoot 'cmdline-tools\latest\bin\android.exe'
        Invoke-Native { & $androidCli --no-metrics "--sdk=$SdkRoot" sdk install @missing | Out-Null } 'android sdk install'
        $stillMissing = @($missing | Where-Object { -not (Test-Path (Join-Path $SdkRoot ($_ -replace '/', '\'))) })
        if ($stillMissing.Count -gt 0) { throw "SDK packages not installed: $($stillMissing -join ', ')" }
    }
    $platformTools = Join-Path $SdkRoot 'platform-tools'
    Add-UserPath $platformTools
    if (-not (Test-Path (Join-Path $platformTools 'adb.exe'))) { throw 'adb.exe missing after SDK install.' }
    Write-Ok "$SdkRoot  ($($packages -join ', '))"
}

# --- 4. Export templates ----------------------------------------------------------------------------
if (-not $SkipExportTemplates) {
    Write-Step "Godot export templates $GodotVersion"
    if (-not (Test-Path (Join-Path $TemplatesDir 'android_debug.apk'))) {
        $tpz = Join-Path $DownloadDir "Godot_v$GodotVersion-stable_export_templates.tpz"
        Get-Download "https://github.com/godotengine/godot/releases/download/$GodotVersion-stable/Godot_v$GodotVersion-stable_export_templates.tpz" $tpz
        $extract = Join-Path $DownloadDir 'templates-extract'
        Remove-Item $extract -Recurse -Force -ErrorAction SilentlyContinue
        New-Item -ItemType Directory -Force $extract, $TemplatesDir | Out-Null
        Invoke-Native { & $Tar -xf $tpz -C $extract } 'Extracting export templates'
        Move-Item (Join-Path $extract 'templates\*') $TemplatesDir -Force
        Remove-Item $extract -Recurse -Force
    }
    Write-Ok $TemplatesDir
}

# --- 5. Godot editor settings -----------------------------------------------------------------------
Write-Step 'Godot editor settings'
$settings = @{
    'export/android/java_sdk_path'    = ConvertTo-GodotPath $jdkHome.FullName
    'export/android/android_sdk_path' = ConvertTo-GodotPath $SdkRoot
}
$codeCmd = $null
if (-not $SkipVSCode) {
    $codeExe = (Get-Command code -ErrorAction SilentlyContinue).Source
    if ($codeExe) {
        $codeDir = Split-Path $codeExe
        $candidate = @((Join-Path $codeDir 'bin\code.cmd'), (Join-Path (Split-Path $codeDir) 'bin\code.cmd'), $codeExe) |
            Where-Object { Test-Path $_ } | Select-Object -First 1
        $codeCmd = $candidate
        $guiExe = @((Join-Path $codeDir 'Code.exe'), (Join-Path (Split-Path $codeDir) 'Code.exe')) |
            Where-Object { Test-Path $_ } | Select-Object -First 1
        if ($guiExe) {
            $settings['text_editor/external/use_external_editor'] = 'true'
            $settings['text_editor/external/exec_path'] = ConvertTo-GodotPath $guiExe
            $settings['text_editor/external/exec_flags'] = '"{project} --goto {file}:{line}:{col}"'
        }
    }
}
$settingsFile = Set-GodotEditorSettings $settings
Write-Ok $settingsFile

# --- 6. VS Code extension ---------------------------------------------------------------------------
if (-not $SkipVSCode) {
    Write-Step 'VS Code extension godot-tools'
    if ($codeCmd) {
        Invoke-Native { & $codeCmd --install-extension geequlim.godot-tools --force | Out-Null } 'code --install-extension'
        Write-Ok 'geequlim.godot-tools'
    } else {
        Write-Warning 'VS Code CLI not found; install the "godot-tools" extension manually.'
    }
}

# --- Summary ----------------------------------------------------------------------------------------
Write-Step 'Done'
Write-Host @"
    GODOT        = $godotConsoleExe
    JAVA_HOME    = $($jdkHome.FullName)
    ANDROID_HOME = $SdkRoot

    Open a NEW terminal and fully restart VS Code (close all windows) so the environment
    changes take effect. .vscode/settings.json uses `${env:GODOT}` for the Godot path.
"@
