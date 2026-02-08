# 1) Copies obs.dll next to bongobs-cat.dll so OBS can load the plugin.
# 2) Copies plugin data (locale, Bango Cat) to every location OBS might use.
# Usage: powershell -ExecutionPolicy Bypass -File fix-obs-plugin-load.ps1 -ObsPath "C:\Program Files\obs-studio"
#        With repo source: add -RepoPath "c:\path\to\Bongobs-Cat-Plugin-Azerty"

param([string]$ObsPath, [string]$RepoPath)

$obsRoot = if ($ObsPath) { $ObsPath } else { Get-Location }
$pluginDir = Join-Path $obsRoot "obs-plugins\64bit"
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
$binPluginDir = Join-Path $obsRoot "bin\64bit\obs-plugins\64bit"
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
    $targets = @(
        (Join-Path $obsRoot "data\obs-plugins\bongobs-cat"),
        (Join-Path $obsRoot "bin\64bit\data\obs-plugins\bongobs-cat"),
        (Join-Path $env:ProgramData "obs-studio\plugins\bongobs-cat\data")
    )
    foreach ($dest in $targets) {
        $localeDest = Join-Path $dest "locale\en-US.ini"
        if (-not (Test-Path $localeDest)) {
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
}

Write-Host "Restart OBS and try adding the Bongo Cat source again." -ForegroundColor Cyan
