# Copy bongobs-cat.dll from OBS build and create Bango.Cat.AZERTY.zip
# Run from: Bongobs-Cat-Plugin-Azerty root (parent of release/)
# Usage: .\release\copy_dll_and_zip.ps1 [-ObsBuildPath "C:\path\to\obs-studio"]

param(
    [string]$ObsBuildPath = "c:\Users\killi\Desktop\obs studio\obs-studio"
)

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent $scriptDir

$dllRelWithDeb = Join-Path $ObsBuildPath "build_x64\rundir\RelWithDebInfo\obs-plugins\64bit\bongobs-cat.dll"
$dllRelease = Join-Path $ObsBuildPath "build_x64\rundir\Release\obs-plugins\64bit\bongobs-cat.dll"
$destDir = Join-Path $scriptDir "obs-plugins\64bit"
$zipPath = Join-Path $repoRoot "Bango.Cat.AZERTY.zip"

if (Test-Path $dllRelWithDeb) {
    Copy-Item $dllRelWithDeb $destDir -Force
    Write-Host "Copied RelWithDebInfo bongobs-cat.dll to $destDir"
} elseif (Test-Path $dllRelease) {
    Copy-Item $dllRelease $destDir -Force
    Write-Host "Copied Release bongobs-cat.dll to $destDir"
} else {
    Write-Warning "DLL not found at $dllRelWithDeb or $dllRelease. Build OBS first (cmake --preset windows-x64; cmake --build build_x64 --config RelWithDebInfo)."
    exit 1
}

Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
Compress-Archive -Path (Join-Path $scriptDir "bin"), (Join-Path $scriptDir "data"), (Join-Path $scriptDir "obs-plugins") -DestinationPath $zipPath -Force
Write-Host "Created $zipPath"
