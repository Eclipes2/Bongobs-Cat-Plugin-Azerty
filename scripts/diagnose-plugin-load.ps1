# Tries to load bongobs-cat.dll and shows the Windows error code.
# Usage (from OBS folder):  .\diagnose-plugin-load.ps1
# Or:  .\diagnose-plugin-load.ps1 -ObsPath "C:\Program Files\obs-studio"

param([string]$ObsPath)

$ErrorActionPreference = "Stop"
$obsRoot = if ($ObsPath) { $ObsPath } else { Get-Location }

$dllPath = Join-Path $obsRoot "obs-plugins\64bit\bongobs-cat.dll"
if (-not (Test-Path $dllPath)) {
    Write-Host "DLL not found: $dllPath" -ForegroundColor Red
    Write-Host "Set OBS root in the script or run from OBS installation folder."
    exit 1
}

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
    Write-Host "Found obs.dll in: $dllSearchDir" -ForegroundColor Gray
} else {
    Write-Host "obs.dll not found under $obsRoot (OBS may use a different layout)." -ForegroundColor Yellow
}

# Add OBS folder to DLL search path so obs.dll (and other deps) are found
[Loader]::SetDllDirectory($dllSearchDir) | Out-Null
$err = 0
try {
    $h = [Loader]::LoadLibraryEx($dllPath, [IntPtr]::Zero, 0)
    if ($h -eq [IntPtr]::Zero) {
        $err = [System.Runtime.InteropServices.Marshal]::GetLastWin32Error()
        Write-Host "LoadLibrary FAILED. Windows error code: $err" -ForegroundColor Red
        $msg = @{
            126 = "Module not found (e.g. missing dependency DLL)"
            127 = "Procedure not found - OBS version mismatch (rebuild plugin with your OBS version)"
            193 = "Not a valid Win32 application (e.g. 32-bit DLL with 64-bit OBS)"
        }
        if ($msg[$err]) { Write-Host $msg[$err] -ForegroundColor Yellow }
        if ($err -eq 126) {
            Write-Host "Checking dependencies..." -ForegroundColor Cyan
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
                    if (-not $d.Path) { Write-Host "  Missing: obs.dll (not found under $obsRoot)" -ForegroundColor Red }
                    else { Write-Host "  OK: obs.dll at $($d.Path.FullName)" -ForegroundColor Green }
                } else {
                    if (-not (Test-Path $d.Path)) { Write-Host "  Missing file: $($d.Name)" -ForegroundColor Red }
                    else {
                        $h2 = [Loader]::LoadLibraryEx($d.Path, [IntPtr]::Zero, 0)
                        if ($h2 -eq [IntPtr]::Zero) {
                            $e2 = [System.Runtime.InteropServices.Marshal]::GetLastWin32Error()
                            Write-Host "  Load failed: $($d.Name) (error $e2)" -ForegroundColor Red
                        } else {
                            Write-Host "  OK: $($d.Name)" -ForegroundColor Green
                            [Loader]::FreeLibrary($h2) | Out-Null
                        }
                    }
                }
            }
            [Loader]::SetDllDirectory($null) | Out-Null
            if (-not $obsDll) {
                Write-Host "" -ForegroundColor Gray
                Write-Host "obs.dll is missing in your OBS folder. When OBS runs, it normally finds obs.dll next to obs64.exe." -ForegroundColor Yellow
                Write-Host "Check: 1) Run OBS and add Bongo Cat - it may work (OBS sets its own paths). 2) Or reinstall OBS if the install is broken." -ForegroundColor Yellow
            } else {
                Write-Host "Workaround: copy MSVCP140.dll, VCRUNTIME140.dll, VCRUNTIME140_1.dll from C:\Windows\System32 to: $obsRoot\obs-plugins\64bit\" -ForegroundColor Gray
            }
        }
    } else {
        Write-Host "DLL loaded successfully." -ForegroundColor Green
        [Loader]::FreeLibrary($h) | Out-Null
    }
} finally {
    [Loader]::SetDllDirectory($null) | Out-Null
}
