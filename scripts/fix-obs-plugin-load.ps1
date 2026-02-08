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
if (-not (Test-Path $destObsDll)) {
    try {
        Copy-Item -Path $obsDll.FullName -Destination $destObsDll -Force
        Write-Host "Copied obs.dll to obs-plugins\64bit" -ForegroundColor Green
    } catch {
        Write-Host "Copy obs.dll failed (try run as Administrator): $_" -ForegroundColor Red
        exit 1
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
