<#
.SYNOPSIS
    Creates the release (upload) keystore for Google Play, outside the repository.

.DESCRIPTION
    Writes to %USERPROFILE%\.laser-detumbling\ (access restricted to the current Windows user):
      release.keystore     RSA 2048 key, alias "upload", valid 10000 days
      release.properties   path, alias and password, read by tools\build_android.ps1
    Godot requires the keystore password and the key password to be identical.

    With Play App Signing (mandatory for new apps) this is the *upload key*: Google re-signs the
    app for distribution, and a lost upload key can be reset through the Play Console.
    BACK UP THE FOLDER ANYWAY (e.g. password manager + offline copy). Never commit it.

.PARAMETER GeneratePassword
    Generate a strong random password instead of asking for one.

.PARAMETER DistinguishedName
    Certificate subject. Visible to anyone who inspects the app's certificate.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File tools\create_release_keystore.ps1
#>
[CmdletBinding()]
param(
    [switch]$GeneratePassword,
    [string]$DistinguishedName = 'CN=Laser De-Tumbling'
)

$ErrorActionPreference = 'Stop'

$KeyDir     = Join-Path $env:USERPROFILE '.laser-detumbling'
$Keystore   = Join-Path $KeyDir 'release.keystore'
$Properties = Join-Path $KeyDir 'release.properties'
$Alias      = 'upload'

if (Test-Path $Keystore) {
    throw "$Keystore already exists. Refusing to overwrite a signing key - delete it manually only if you are sure."
}

$javaHome = [Environment]::GetEnvironmentVariable('JAVA_HOME')
if (-not $javaHome) { $javaHome = [Environment]::GetEnvironmentVariable('JAVA_HOME', 'User') }
$keytool = Join-Path $javaHome 'bin\keytool.exe'
if (-not (Test-Path $keytool)) { throw "keytool not found (JAVA_HOME=$javaHome). Run tools\setup_windows.ps1 first." }

if ($GeneratePassword) {
    $bytes = New-Object byte[] 24
    [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
    # URL-safe base64 without padding: 32 characters, no characters that need escaping.
    $password = [Convert]::ToBase64String($bytes).TrimEnd('=').Replace('+', '-').Replace('/', '_')
} else {
    $secure = Read-Host 'Choose a keystore password (min. 12 characters)' -AsSecureString
    $password = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure))
    if ($password.Length -lt 12) { throw 'Password too short.' }
}

New-Item -ItemType Directory -Force $KeyDir | Out-Null
# Restrict the folder to the current user (remove inherited permissions).
& icacls $KeyDir /inheritance:r /grant:r "$($env:USERNAME):(OI)(CI)F" | Out-Null

$previous = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
& $keytool -genkeypair -v -keystore $Keystore -storetype PKCS12 -alias $Alias -keyalg RSA -keysize 2048 `
    -validity 10000 -storepass $password -keypass $password -dname $DistinguishedName 2>&1 | Out-Null
$code = $LASTEXITCODE
$ErrorActionPreference = $previous
if ($code -ne 0 -or -not (Test-Path $Keystore)) { throw "keytool failed with exit code $code" }

Set-Content -Path $Properties -Encoding ASCII -Value @(
    "keystore=$Keystore",
    "alias=$Alias",
    "password=$password"
)

Write-Host "Created release keystore:" -ForegroundColor Green
Write-Host "  $Keystore"
Write-Host "  $Properties   (contains the password)"
Write-Host ""
Write-Host "BACK UP this folder now (password manager + offline copy). Never commit it." -ForegroundColor Yellow
