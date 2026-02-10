# Build Bango.Cat.AZERTY.zip from OBS build output and repo (Live2DCubismCore.dll).
# Maintainer only. Run after: cmake --build build_x64 --target bongobs-cat --config Release
#
# Usage:
#   .\scripts\build-release-zip.ps1 -ObsRundir "C:\...\obs-studio\build_x64\rundir\Release" -RepoPath "C:\...\Bongobs-Cat-Plugin-Azerty"
#
# The zip contains obs-plugins/64bit/, data/obs-plugins/bongobs-cat/, and bin/64bit/obs-plugins/64bit/
# (plugin + obs.dll + all bin\64bit DLLs in both load paths). Extract into the OBS folder so obs-plugins,
# data, and bin merge with the existing folders. If the plugin still fails to load, run fix-obs-plugin-load.ps1.

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

# OBS 32 puts plugins in obs-plugins\64bit\; older builds may use bin\64bit\obs-plugins\
$pluginDll = Join-Path $ObsRundir "obs-plugins\64bit\bongobs-cat.dll"
if (-not (Test-Path $pluginDll)) {
    $pluginDll = Join-Path $ObsRundir "bin\64bit\obs-plugins\bongobs-cat.dll"
}
$pluginDataDir = Join-Path $ObsRundir "data\obs-plugins\bongobs-cat"
$releaseDataDir = Join-Path $RepoPath "release\data\obs-plugins\bongobs-cat"
$live2dDll = Join-Path $RepoPath "CubismSdk\Core\dll\windows\x86_64\Live2DCubismCore.dll"

if (-not (Test-Path $pluginDll)) {
    Write-Host "Plugin DLL not found. Tried: obs-plugins\64bit\bongobs-cat.dll and bin\64bit\obs-plugins\bongobs-cat.dll under $ObsRundir" -ForegroundColor Red
    exit 1
}
Write-Host "Using plugin DLL: $pluginDll" -ForegroundColor Gray
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

    # Also install plugin under bin/64bit/obs-plugins/64bit (OBS may load plugins from there)
    $binPluginDest = Join-Path $tempDir "bin\64bit\obs-plugins\64bit"
    New-Item -ItemType Directory -Path $binPluginDest -Force | Out-Null
    Copy-Item -Path (Join-Path $dest64 "*") -Destination $binPluginDest -Recurse -Force
    Write-Host "Plugin also in bin/64bit/obs-plugins/64bit (both OBS load paths)" -ForegroundColor Green

    # Plugin data: prefer release/ (all modes + standard_azerty), then ObsRundir, then repo data + Resources
    $destData = Join-Path $tempDir "data\obs-plugins\bongobs-cat"
    New-Item -ItemType Directory -Path (Split-Path $destData -Parent) -Force | Out-Null
    if (Test-Path $releaseDataDir) {
        Copy-Item -Path $releaseDataDir -Destination $destData -Recurse -Force
        Write-Host "Using release data (all modes): $releaseDataDir" -ForegroundColor Green
    } elseif (Test-Path $pluginDataDir) {
        Copy-Item -Path $pluginDataDir -Destination $destData -Recurse -Force
    } else {
        Copy-Item -Path (Join-Path $RepoPath "data\*") -Destination $destData -Recurse -Force
        $bangoDest = Join-Path $destData "Bango Cat"
        New-Item -ItemType Directory -Path $bangoDest -Force | Out-Null
        Copy-Item -Path (Join-Path $RepoPath "Resources\Bango Cat\*") -Destination $bangoDest -Recurse -Force
    }

    if (Test-Path $OutputZip) { Remove-Item $OutputZip -Force }
    Compress-Archive -Path (Join-Path $tempDir "obs-plugins"), (Join-Path $tempDir "data"), (Join-Path $tempDir "bin") -DestinationPath $OutputZip -CompressionLevel Optimal
    Write-Host "Created: $OutputZip" -ForegroundColor Cyan
} finally {
    Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
}
