# 1) Copies obs.dll next to bongobs-cat.dll so OBS can load the plugin.
# 2) Copies plugin data (locale, Bango Cat) to every location OBS might use.
# Usage: powershell -ExecutionPolicy Bypass -File fix-obs-plugin-load.ps1 -ObsPath "C:\Program Files\obs-studio"
#        With repo source: add -RepoPath "c:\path\to\Bongobs-Cat-Plugin-Azerty"
#        If OBS shows plugin twice: -RemoveFromProgramData. If error 126: -UseBin64Only. If source not in list after -UseBin64Only: -RestoreToRoot.

param([string]$ObsPath, [string]$RepoPath, [switch]$RemoveFromProgramData, [switch]$UseBin64Only, [switch]$RestoreToRoot)

$obsRoot = if ($ObsPath) { $ObsPath } else { Get-Location }
if ($UseBin64Only) { $RemoveFromProgramData = $true }

$pluginDir = Join-Path $obsRoot "obs-plugins\64bit"
$binPluginDir = Join-Path $obsRoot "bin\64bit\obs-plugins\64bit"
# If source is missing from root but present in bin (e.g. after -UseBin64Only), restore so OBS can list "Bongo Cat"
if ($RestoreToRoot) {
    foreach ($d in @("bongobs-cat.dll", "Live2DCubismCore.dll")) {
        $src = Join-Path $binPluginDir $d
        $dest = Join-Path $pluginDir $d
        if ((Test-Path $src) -and (-not (Test-Path $dest))) {
            try {
                if (-not (Test-Path $pluginDir)) { New-Item -ItemType Directory -Path $pluginDir -Force | Out-Null }
                Copy-Item -Path $src -Destination $dest -Force
                Write-Host "Restored to root (so OBS lists the source): $d" -ForegroundColor Green
            } catch { Write-Host "Restore $d failed (run as Administrator): $_" -ForegroundColor Red }
        }
    }
}

# If OBS shows "bongobs-cat" twice, remove the ProgramData copy so only Program Files is used.
$programDataPlugin = Join-Path $env:ProgramData "obs-studio\plugins\bongobs-cat"
if ($RemoveFromProgramData -and (Test-Path $programDataPlugin)) {
    try {
        Remove-Item -Path $programDataPlugin -Recurse -Force
        Write-Host "Removed plugin from ProgramData (single install now in Program Files): $programDataPlugin" -ForegroundColor Green
    } catch {
        Write-Host "Could not remove ProgramData plugin (run as Administrator): $_" -ForegroundColor Red
    }
}
if ($RemoveFromProgramData) {
    # Skip installing to ProgramData below; $programDataPlugin already set for data targets to exclude
}
$bongobsDll = Join-Path $pluginDir "bongobs-cat.dll"

if (-not (Test-Path $bongobsDll)) {
    Write-Host "bongobs-cat.dll not found in $pluginDir. Extract Bango.Cat.AZERTY.zip to the OBS installation root first." -ForegroundColor Red
    exit 1
}

# --- 1) obs.dll next to plugin ---
$obsDll = Get-ChildItem -Path $obsRoot -Recurse -Filter "obs.dll" -ErrorAction SilentlyContinue | Where-Object { $_.FullName -notmatch "obs-plugins" } | Select-Object -First 1
if (-not $obsDll) {
    Write-Host "obs.dll not found under $obsRoot. Is OBS installed correctly?" -ForegroundColor Red
    exit 1
}

$destObsDll = Join-Path $pluginDir "obs.dll"
try {
    Copy-Item -Path $obsDll.FullName -Destination $destObsDll -Force
    Write-Host "Copied obs.dll to obs-plugins\64bit" -ForegroundColor Green
} catch {
    Write-Host "Copy obs.dll failed (try run as Administrator): $_" -ForegroundColor Red
    exit 1
}

# --- 1a) VC++ runtime DLLs next to plugin (avoids LoadLibrary error 126 when loader path differs) ---
$vcDlls = @("MSVCP140.dll", "VCRUNTIME140.dll", "VCRUNTIME140_1.dll")
$system32 = [Environment]::GetFolderPath("System")  # C:\Windows\System32 (64-bit DLLs on 64-bit Windows)
foreach ($d in $vcDlls) {
    $src = Join-Path $system32 $d
    if (Test-Path $src) {
        try {
            Copy-Item -Path $src -Destination (Join-Path $pluginDir $d) -Force
        } catch { Write-Host "Copy $d to obs-plugins\64bit failed: $_" -ForegroundColor Yellow }
    } else {
        Write-Host "VC++ DLL not found: $src (install VC++ 2015-2022 x64 redist if needed)" -ForegroundColor Yellow
    }
}

# --- 1b) Copy all DLLs from bin\64bit next to plugin (OBS may restrict loader to plugin dir only) ---
# Layout ref: backup/ shows bin\64bit has obs.dll, Qt*.dll and subdirs iconengines, imageformats, platforms, styles
$bin64 = Join-Path $obsRoot "bin\64bit"
if (Test-Path $bin64) {
    $copied = 0
    Get-ChildItem -Path $bin64 -Filter "*.dll" -File -ErrorAction SilentlyContinue | ForEach-Object {
        try {
            Copy-Item -Path $_.FullName -Destination (Join-Path $pluginDir $_.Name) -Force
            $copied++
        } catch { Write-Host "Copy $($_.Name) failed: $_" -ForegroundColor Yellow }
    }
    # Copy DLLs from bin\64bit subdirs (e.g. platforms\qwindows.dll) so obs.dll can load Qt plugins
    Get-ChildItem -Path $bin64 -Directory -ErrorAction SilentlyContinue | ForEach-Object {
        $subDest = Join-Path $pluginDir $_.Name
        if (-not (Test-Path $subDest)) { New-Item -ItemType Directory -Path $subDest -Force | Out-Null }
        Get-ChildItem -Path $_.FullName -Filter "*.dll" -File -ErrorAction SilentlyContinue | ForEach-Object {
            try {
                Copy-Item -Path $_.FullName -Destination (Join-Path $subDest $_.Name) -Force
                $copied++
            } catch { }
        }
    }
    if ($copied -gt 0) {
        Write-Host "Copied $copied DLL(s) from bin\64bit (and subdirs) to obs-plugins\64bit" -ForegroundColor Green
    }
}

# --- 1c) Also install plugin under bin\64bit\obs-plugins\64bit (OBS may load from there) ---
if (Test-Path $bin64) {
    if (-not (Test-Path $binPluginDir)) { New-Item -ItemType Directory -Path $binPluginDir -Force | Out-Null }
    $dlls = @("bongobs-cat.dll", "Live2DCubismCore.dll", "obs.dll") + $vcDlls
    foreach ($d in $dlls) {
        $src = if ($d -eq "obs.dll") { $obsDll.FullName } elseif ($vcDlls -contains $d) { Join-Path $system32 $d } else { Join-Path $pluginDir $d }
        if ((Test-Path $src) -and (Test-Path $binPluginDir)) {
            try {
                Copy-Item -Path $src -Destination (Join-Path $binPluginDir $d) -Force
            } catch { Write-Host "Copy $d to bin\64bit\obs-plugins\64bit failed: $_" -ForegroundColor Yellow }
        }
    }
    # Copy all bin\64bit DLLs and subdirs to bin plugin dir too so loading from there has deps
    Get-ChildItem -Path $bin64 -Filter "*.dll" -File -ErrorAction SilentlyContinue | ForEach-Object {
        try { Copy-Item -Path $_.FullName -Destination (Join-Path $binPluginDir $_.Name) -Force } catch { }
    }
    Get-ChildItem -Path $bin64 -Directory -ErrorAction SilentlyContinue | ForEach-Object {
        $subDest = Join-Path $binPluginDir $_.Name
        if (-not (Test-Path $subDest)) { New-Item -ItemType Directory -Path $subDest -Force | Out-Null }
        Get-ChildItem -Path $_.FullName -Filter "*.dll" -File -ErrorAction SilentlyContinue | ForEach-Object {
            try { Copy-Item -Path $_.FullName -Destination (Join-Path $subDest $_.Name) -Force } catch { }
        }
    }
    if (Test-Path (Join-Path $binPluginDir "bongobs-cat.dll")) {
        Write-Host "Plugin also installed in bin\64bit\obs-plugins\64bit" -ForegroundColor Green
    }
}

# --- 1d) Install plugin in ProgramData (skip if -RemoveFromProgramData to avoid OBS seeing it twice) ---
if (-not $RemoveFromProgramData) {
    $programDataBin64 = Join-Path $programDataPlugin "bin\64bit"
    if (-not (Test-Path $programDataBin64)) { New-Item -ItemType Directory -Path $programDataBin64 -Force | Out-Null }
    $copiedPd = 0
    Get-ChildItem -Path $pluginDir -Filter "*.dll" -File -ErrorAction SilentlyContinue | ForEach-Object {
        try {
            Copy-Item -Path $_.FullName -Destination (Join-Path $programDataBin64 $_.Name) -Force
            $copiedPd++
        } catch { }
    }
    Get-ChildItem -Path $pluginDir -Directory -ErrorAction SilentlyContinue | ForEach-Object {
        $subDest = Join-Path $programDataBin64 $_.Name
        if (-not (Test-Path $subDest)) { New-Item -ItemType Directory -Path $subDest -Force | Out-Null }
        Get-ChildItem -Path $_.FullName -Filter "*.dll" -File -ErrorAction SilentlyContinue | ForEach-Object {
            try {
                Copy-Item -Path $_.FullName -Destination (Join-Path $subDest $_.Name) -Force
                $copiedPd++
            } catch { }
        }
    }
    if ($copiedPd -gt 0) {
        Write-Host "Plugin also installed in ProgramData (OBS recommended path): $programDataBin64" -ForegroundColor Green
    }
}

# --- 2) Plugin data: find source (OBS root data or repo release) ---
$dataAtRoot = Join-Path $obsRoot "data\obs-plugins\bongobs-cat"
$dataSource = $dataAtRoot
if (-not (Test-Path (Join-Path $dataAtRoot "locale\en-US.ini"))) {
    if ($RepoPath -and (Test-Path (Join-Path $RepoPath "release\data\obs-plugins\bongobs-cat\locale\en-US.ini"))) {
        $dataSource = Join-Path $RepoPath "release\data\obs-plugins\bongobs-cat"
        Write-Host "Using plugin data from repo: $dataSource" -ForegroundColor Gray
    } else {
        Write-Host "Plugin data not found at OBS root. Extract Bango.Cat.AZERTY.zip to OBS root, or run with -RepoPath 'path\to\repo'." -ForegroundColor Yellow
        $dataSource = $null
    }
}

if ($dataSource) {
    $dataSourceNorm = [System.IO.Path]::GetFullPath($dataSource)
    $targets = @(
        (Join-Path $obsRoot "data\obs-plugins\bongobs-cat"),
        (Join-Path $obsRoot "bin\64bit\data\obs-plugins\bongobs-cat")
    )
    if (-not $RemoveFromProgramData) { $targets += (Join-Path $programDataPlugin "data") }
    foreach ($dest in $targets) {
        $destNorm = [System.IO.Path]::GetFullPath($dest)
        if ($destNorm -eq $dataSourceNorm) {
            Write-Host "Plugin data already at: $dest" -ForegroundColor Gray
            continue
        }
        $parent = Split-Path $dest -Parent
        if (-not (Test-Path $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
        try {
            Copy-Item -Path $dataSource -Destination $dest -Recurse -Force
            Write-Host "Copied plugin data to: $dest" -ForegroundColor Green
        } catch {
            Write-Host "Copy to $dest failed (try run as Administrator): $_" -ForegroundColor Red
        }
    }
}

# UseBin64Only: remove plugin from root obs-plugins\64bit so OBS only loads it from bin\64bit\obs-plugins\64bit (where loading works).
# Skip removal if we just restored to root so the source appears in OBS.
if ($UseBin64Only -and -not $RestoreToRoot) {
    $rootDll = Join-Path $pluginDir "bongobs-cat.dll"
    $rootLive2D = Join-Path $pluginDir "Live2DCubismCore.dll"
    foreach ($f in @($rootDll, $rootLive2D)) {
        if (Test-Path $f) {
            try {
                Remove-Item -Path $f -Force
                Write-Host "Removed from root (OBS will use bin\64bit\obs-plugins\64bit only): $f" -ForegroundColor Green
            } catch {
                Write-Host "Could not remove $f (run as Administrator): $_" -ForegroundColor Red
            }
        }
    }
}

Write-Host "Restart OBS and try adding the Bongo Cat source again." -ForegroundColor Cyan
