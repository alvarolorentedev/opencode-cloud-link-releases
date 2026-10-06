# Downloads one checksum-verified Windows tray installer.
[CmdletBinding()]
param(
    [string]$Version = $env:VERSION,
    [string]$Repository = 'alvarolorentedev/opencode-cloud-link-releases',
    [switch]$Silent
)
$ErrorActionPreference = 'Stop'
if (-not $Version) {
    $Version = (Invoke-RestMethod "https://api.github.com/repos/$Repository/releases/latest").tag_name
}
$Version = $Version.TrimStart('v')
if ($Version -notmatch '^\d+\.\d+\.\d+$') { throw 'Invalid release version' }
$architecture = [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString()
if ($architecture -ne 'X64') { throw 'MVP installers support Windows x64 only; Windows ARM64 is not currently distributed' }
$name = 'opencode-cloudlink_windows_amd64.exe'
$url = "https://github.com/$Repository/releases/download/v$Version/$name"
$temporary = Join-Path ([IO.Path]::GetTempPath()) ([Guid]::NewGuid().ToString())
New-Item -ItemType Directory -Path $temporary | Out-Null
try {
    $installer = Join-Path $temporary $name
    Invoke-WebRequest $url -OutFile $installer
    $digest = ((Invoke-WebRequest "$url.sha256").Content -split '\s+')[0]
    if ($digest -notmatch '^[a-f0-9]{64}$' -or (Get-FileHash $installer -Algorithm SHA256).Hash.ToLower() -ne $digest) { throw 'Installer checksum mismatch' }
    $arguments = @()
    if ($Silent) { $arguments += '/S' }
    $launch = @{ FilePath = $installer; Wait = $true; PassThru = $true }
    if ($arguments.Count) { $launch.ArgumentList = $arguments }
    $process = Start-Process @launch
    if ($process.ExitCode -notin @(0, 3010)) { throw "Installer exited with code $($process.ExitCode)" }
} finally {
    Remove-Item -Recurse -Force $temporary
}
