# Build Bango.Cat.AZERTY.zip from OBS build output and repo (Live2DCubismCore.dll).
# Maintainer only. Run after: cmake --build build_x64 --target bongobs-cat --config Release
#
# Usage:
#   .\scripts\build-release-zip.ps1 -ObsRundir "C:\...\obs-studio\build_x64\rundir\Release" -RepoPath "C:\...\Bongobs-Cat-Plugin-Azerty"
#
# The zip contains obs-plugins/64bit/ (plugin DLLs + obs.dll + all bin\64bit DLLs so it loads without fix script)
# and data/obs-plugins/bongobs-cat/. Users just extract into their OBS folder and it works.

param(
    [Parameter(Mandatory = $true)]
    [string]$ObsRundir,
    [Parameter(Mandatory = $true)]
    [string]$RepoPath,
    [string]$OutputZip = ""
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $ObsRundir)) {
    Write-Host "ObsRundir not found: $ObsRundir" -ForegroundColor Red
    exit 1
}
if (-not (Test-Path $RepoPath)) {
    Write-Host "RepoPath not found: $RepoPath" -ForegroundColor Red
    exit 1
}

$pluginDll = Join-Path $ObsRundir "bin\64bit\obs-plugins\bongobs-cat.dll"
$pluginDataDir = Join-Path $ObsRundir "data\obs-plugins\bongobs-cat"
$live2dDll = Join-Path $RepoPath "CubismSdk\Core\dll\windows\x86_64\Live2DCubismCore.dll"

if (-not (Test-Path $pluginDll)) {
    Write-Host "Plugin DLL not found: $pluginDll" -ForegroundColor Red
    exit 1
}
if (-not (Test-Path $live2dDll)) {
    Write-Host "Live2DCubismCore.dll not found: $live2dDll" -ForegroundColor Red
    exit 1
}

if ($OutputZip -eq "") {
    $OutputZip = Join-Path $RepoPath "Bango.Cat.AZERTY.zip"
}

$tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "bongobs-cat-release-$(Get-Random)"
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

try {
    $dest64 = Join-Path $tempDir "obs-plugins\64bit"
    New-Item -ItemType Directory -Path $dest64 -Force | Out-Null
    Copy-Item -Path $pluginDll -Destination $dest64 -Force
    Copy-Item -Path $live2dDll -Destination $dest64 -Force

    # Bundle all DLLs from OBS build bin\64bit so the plugin loads without running the fix script (self-contained zip)
    $bin64 = Join-Path $ObsRundir "bin\64bit"
    if (Test-Path $bin64) {
        $copied = 0
        Get-ChildItem -Path $bin64 -Filter "*.dll" -File -ErrorAction SilentlyContinue | ForEach-Object {
            Copy-Item -Path $_.FullName -Destination (Join-Path $dest64 $_.Name) -Force
            $copied++
        }
        Get-ChildItem -Path $bin64 -Directory -ErrorAction SilentlyContinue | ForEach-Object {
            $subDest = Join-Path $dest64 $_.Name
            New-Item -ItemType Directory -Path $subDest -Force | Out-Null
            Get-ChildItem -Path $_.FullName -Filter "*.dll" -File -ErrorAction SilentlyContinue | ForEach-Object {
                Copy-Item -Path $_.FullName -Destination (Join-Path $subDest $_.Name) -Force
                $copied++
            }
        }
        Write-Host "Bundled $copied DLL(s) from OBS bin\64bit (zip will work without fix script)" -ForegroundColor Green
    }

    # VC++ runtimes (in case OBS build dir doesn't have them; user may need them next to plugin)
    $sys32 = [Environment]::GetFolderPath("System")
    @("MSVCP140.dll", "VCRUNTIME140.dll", "VCRUNTIME140_1.dll") | ForEach-Object {
        $src = Join-Path $sys32 $_
        if (Test-Path $src) { Copy-Item -Path $src -Destination (Join-Path $dest64 $_) -Force }
    }

    $destData = Join-Path $tempDir "data\obs-plugins\bongobs-cat"
    if (Test-Path $pluginDataDir) {
        New-Item -ItemType Directory -Path (Split-Path $destData -Parent) -Force | Out-Null
        Copy-Item -Path $pluginDataDir -Destination $destData -Recurse -Force
    } else {
        New-Item -ItemType Directory -Path $destData -Force | Out-Null
        Copy-Item -Path (Join-Path $RepoPath "data\*") -Destination $destData -Recurse -Force
        $bangoDest = Join-Path $destData "Bango Cat"
        New-Item -ItemType Directory -Path $bangoDest -Force | Out-Null
        Copy-Item -Path (Join-Path $RepoPath "Resources\*") -Destination $bangoDest -Recurse -Force
    }

    if (Test-Path $OutputZip) { Remove-Item $OutputZip -Force }
    Compress-Archive -Path (Join-Path $tempDir "obs-plugins"), (Join-Path $tempDir "data") -DestinationPath $OutputZip -CompressionLevel Optimal
    Write-Host "Created: $OutputZip" -ForegroundColor Cyan
} finally {
    Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
}
