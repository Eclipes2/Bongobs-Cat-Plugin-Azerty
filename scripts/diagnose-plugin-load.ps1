# Tries to load bongobs-cat.dll and shows the Windows error code and dependency details.
# Usage:  .\diagnose-plugin-load.ps1 -ObsPath "C:\Program Files\obs-studio"
#        .\diagnose-plugin-load.ps1 -ObsPath "C:\Program Files\obs-studio" -ReportPath "diagnose-report.txt"
# Add -SimulateOBS to load WITHOUT adding bin\64bit to path (reproduces the error OBS gets).
param([string]$ObsPath, [switch]$SimulateOBS, [string]$ReportPath = "")

$ErrorActionPreference = "Stop"
$obsRoot = if ($ObsPath) { $ObsPath } else { Get-Location }

function Write-Diag {
    param([string]$Text, [string]$Color = "White")
    if ($Color) { Write-Host $Text -ForegroundColor $Color }
    if ($script:ReportStream) { $script:ReportStream.WriteLine($Text) }
}
$script:ReportStream = $null
if ($ReportPath) {
    $reportFull = if ([System.IO.Path]::IsPathRooted($ReportPath)) { $ReportPath } else { (Join-Path (Get-Location) $ReportPath) }
    $script:ReportStream = [System.IO.StreamWriter]::new($reportFull, $false, [System.Text.Encoding]::UTF8)
    $ReportPath = $reportFull
    Write-Diag "=== Bongo Cat plugin load diagnostic ===" "Cyan"
    Write-Diag "Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" "Gray"
    Write-Diag "OBS root: $obsRoot" "Gray"
    Write-Diag "SimulateOBS: $SimulateOBS" "Gray"
    Write-Diag "" "Gray"
}

# Prefer bin\64bit\obs-plugins\64bit if present (same as OBS)
$dllPath = Join-Path $obsRoot "bin\64bit\obs-plugins\64bit\bongobs-cat.dll"
if (-not (Test-Path $dllPath)) {
    $dllPath = Join-Path $obsRoot "obs-plugins\64bit\bongobs-cat.dll"
}
if (-not (Test-Path $dllPath)) {
    Write-Diag "DLL not found under $obsRoot" "Red"
    if ($script:ReportStream) { $script:ReportStream.Close() }
    exit 1
}
$pluginDir = Split-Path $dllPath -Parent
Write-Diag "Plugin DLL: $dllPath" "Gray"
Write-Diag "Plugin dir:  $pluginDir" "Gray"

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class Loader {
    [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    public static extern bool SetDllDirectory(string path);
    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern IntPtr LoadLibraryEx(string path, IntPtr hFile, uint flags);
    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool FreeLibrary(IntPtr hModule);
}
"@

# Find obs.dll (may be in root or in bin\64bit etc.)
$obsDll = Get-ChildItem -Path $obsRoot -Recurse -Filter "obs.dll" -ErrorAction SilentlyContinue | Where-Object { $_.FullName -notmatch "obs-plugins" } | Select-Object -First 1
$dllSearchDir = $obsRoot
if ($obsDll) {
    $dllSearchDir = $obsDll.DirectoryName
    if (-not $SimulateOBS) { Write-Diag "Found obs.dll in: $dllSearchDir" "Gray" }
}

# SimulateOBS = do NOT set DLL directory, so we see the same failure as OBS
if ($SimulateOBS) {
    Write-Diag "Simulating OBS load (plugin dir only, like OBS)..." "Cyan"
} else {
    [Loader]::SetDllDirectory($dllSearchDir) | Out-Null
}
$err = 0
try {
    $h = [Loader]::LoadLibraryEx($dllPath, [IntPtr]::Zero, 0)
    if ($h -eq [IntPtr]::Zero) {
        $err = [System.Runtime.InteropServices.Marshal]::GetLastWin32Error()
        Write-Diag "LoadLibrary FAILED. Windows error code: $err" "Red"
        $msg = @{
            126 = "Module not found (e.g. missing dependency DLL)"
            127 = "Procedure not found - OBS version mismatch (rebuild plugin with your OBS version)"
            193 = "Not a valid Win32 application (e.g. 32-bit DLL with 64-bit OBS)"
        }
        if ($msg[$err]) { Write-Diag $msg[$err] "Yellow" }
        if ($err -eq 126) {
            Write-Diag "Checking dependencies..." "Cyan"
            $sys32 = [Environment]::GetFolderPath("System")
            $deps = @(
                @{ Name = "obs.dll"; Path = (Get-ChildItem -Path $obsRoot -Recurse -Filter "obs.dll" -ErrorAction SilentlyContinue | Where-Object { $_.FullName -notmatch "obs-plugins" } | Select-Object -First 1) },
                @{ Name = "MSVCP140.dll"; Path = Join-Path $sys32 "MSVCP140.dll" },
                @{ Name = "VCRUNTIME140.dll"; Path = Join-Path $sys32 "VCRUNTIME140.dll" },
                @{ Name = "VCRUNTIME140_1.dll"; Path = Join-Path $sys32 "VCRUNTIME140_1.dll" }
            )
            [Loader]::SetDllDirectory($dllSearchDir) | Out-Null
            foreach ($d in $deps) {
                if ($d.Name -eq "obs.dll") {
                    if (-not $d.Path) { Write-Diag "  Missing: obs.dll (not found under $obsRoot)" "Red" }
                    else { Write-Diag "  OK: obs.dll at $($d.Path.FullName)" "Green" }
                } else {
                    if (-not (Test-Path $d.Path)) { Write-Diag "  Missing file: $($d.Name)" "Red" }
                    else {
                        $h2 = [Loader]::LoadLibraryEx($d.Path, [IntPtr]::Zero, 0)
                        if ($h2 -eq [IntPtr]::Zero) {
                            $e2 = [System.Runtime.InteropServices.Marshal]::GetLastWin32Error()
                            Write-Diag "  Load failed: $($d.Name) (error $e2)" "Red"
                        } else {
                            Write-Diag "  OK: $($d.Name)" "Green"
                            [Loader]::FreeLibrary($h2) | Out-Null
                        }
                    }
                }
            }
            [Loader]::SetDllDirectory($null) | Out-Null
            if (-not $obsDll) {
                Write-Diag "" "Gray"
                Write-Diag "obs.dll is missing in your OBS folder. When OBS runs, it normally finds obs.dll next to obs64.exe." "Yellow"
                Write-Diag "Check: 1) Run OBS and add Bongo Cat - it may work (OBS sets its own paths). 2) Or reinstall OBS if the install is broken." "Yellow"
            } else {
                Write-Diag "Workaround: run fix-obs-plugin-load.ps1 as Administrator (it copies obs.dll, VC++ runtimes, and all bin\64bit DLLs next to the plugin)." "Gray"
            }
            # Compare bin\64bit contents with plugin dir - report DLLs that should be next to the plugin but are missing.
            # Exclude files under bin\64bit\obs-plugins\64bit (that IS the plugin dir - we don't copy it into itself).
            $bin64 = Join-Path $obsRoot "bin\64bit"
            $obsPlugins64 = "obs-plugins\64bit"
            if ($SimulateOBS -and (Test-Path $bin64)) {
                Write-Diag "" "Cyan"
                Write-Diag "DLLs in bin\64bit that are MISSING next to the plugin (these can cause error 126):" "Cyan"
                $missing = @()
                Get-ChildItem -Path $bin64 -Recurse -Filter "*.dll" -File -ErrorAction SilentlyContinue | ForEach-Object {
                    $rel = $_.FullName.Substring($bin64.Length).TrimStart("\")
                    if ($rel.StartsWith($obsPlugins64 + "\") -or $rel -eq $obsPlugins64) { return }
                    $inPlugin = Test-Path (Join-Path $pluginDir $rel)
                    if (-not $inPlugin) { $missing += $rel }
                }
                if ($missing.Count -eq 0) {
                    Write-Diag "  (none - all required DLLs are present next to the plugin)" "Green"
                    Write-Diag "" "Gray"
                    Write-Diag "Retrying LoadLibrary with bin\64bit in DLL search path (like OBS when it runs obs64.exe):" "Cyan"
                    [Loader]::SetDllDirectory($bin64) | Out-Null
                    $hRetry = [Loader]::LoadLibraryEx($dllPath, [IntPtr]::Zero, 0)
                    [Loader]::SetDllDirectory($null) | Out-Null
                    if ($hRetry -ne [IntPtr]::Zero) {
                        Write-Diag "  SUCCESS - plugin loads when bin\64bit is in the path." "Green"
                        Write-Diag "  OBS runs from bin\64bit, so the plugin may load in OBS. Try opening OBS and adding the Bongo Cat source." "Green"
                        [Loader]::FreeLibrary($hRetry) | Out-Null
                    } else {
                        $errRetry = [System.Runtime.InteropServices.Marshal]::GetLastWin32Error()
                        Write-Diag "  Still failed (error $errRetry). Check OBS log (Help -> Log Files -> View Current Log) for details." "Yellow"
                    }
                } else {
                    $missing | ForEach-Object { Write-Diag "  MISSING: $_" "Red" }
                    Write-Diag "Run fix-obs-plugin-load.ps1 as Administrator to copy these." "Yellow"
                }
            }
            # Try to list dependencies with dumpbin and report which are missing next to the plugin
            $dumpbin = $null
            $vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
            if (Test-Path $vswhere) {
                $vsPath = & $vswhere -latest -property installationPath 2>$null
                if ($vsPath) {
                    $dumpbin = Get-ChildItem -Path $vsPath -Recurse -Filter "dumpbin.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
                }
            }
            if (-not $dumpbin) { $dumpbin = Get-Command dumpbin -ErrorAction SilentlyContinue }
            $bin64 = Join-Path $obsRoot "bin\64bit"
            if ($dumpbin) {
                Write-Diag "" "Cyan"
                Write-Diag "Dependencies of bongobs-cat.dll (dumpbin) - checking if present next to plugin or in bin\64bit:" "Cyan"
                $dumpbinExe = if ($dumpbin.Source) { $dumpbin.Source } else { $dumpbin.Path }
                $out = & $dumpbinExe /dependents $dllPath 2>&1
                $depDlls = $out | Where-Object { $_ -match "^\s+(.+\.dll)\s*$" } | ForEach-Object { $matches[1].Trim() }
                foreach ($dep in $depDlls) {
                    $inPlugin = Test-Path (Join-Path $pluginDir $dep)
                    $inBin64 = Test-Path (Join-Path $bin64 $dep)
                    if ($inPlugin) { Write-Diag "  OK (plugin dir): $dep" "Green" }
                    elseif ($inBin64) { Write-Diag "  In bin\64bit (not next to plugin): $dep" "Yellow" }
                    else { Write-Diag "  MISSING: $dep" "Red" }
                }
            }
        }
    } else {
        Write-Diag "DLL loaded successfully." "Green"
        [Loader]::FreeLibrary($h) | Out-Null
    }
} finally {
    [Loader]::SetDllDirectory($null) | Out-Null
}

# Report OBS log location and close report file
$obsLogDir = Join-Path $env:APPDATA "obs-studio"
$obsLogHint = "OBS log: open OBS -> Help -> Log Files -> View Current Log, or check folder: $obsLogDir"
Write-Diag "" "Gray"
Write-Diag $obsLogHint "Cyan"
if ($script:ReportStream) {
    $script:ReportStream.WriteLine("")
    $script:ReportStream.WriteLine("To fix error 126: run fix-obs-plugin-load.ps1 as Administrator with -ObsPath ""$obsRoot""")
    $script:ReportStream.Close()
    $script:ReportStream = $null
    Write-Host "Report written to: $ReportPath" -ForegroundColor Green
}
