# Bongobs Cat OBS Plugin

## AZERTY support (this fork)

This fork adds **native AZERTY keyboard support** to the Bongo Cat OBS plugin, so that keys A, Z, Q, W, etc. on an AZERTY layout drive the correct actions and visuals without any code changes.

### How it works

- The plugin already supports multiple **modes** (standard, keyboard, feixue, etc.). Each mode has a `config.json` that defines which key names trigger which visual slots (keyboard and hand images).
- The default **standard** mode uses **QWERTY** key names: `q`, `e`, `r`, `space`, `a`, `d`, `s`, `w` for the letter keys. On an AZERTY keyboard, the same physical keys send `a`, `e`, `r`, `space`, `q`, `d`, `s`, `z` — so the overlay and actions were misaligned.
- This fork introduces a separate mode **standard_azerty**: a copy of the standard mode where **KeyUse** in `config.json` is set to the key names that AZERTY keyboards actually send. The plugin also uses **obs_module_file()** so it loads config and assets from the plugin data folder, so all 6 modes (including standard_azerty) appear when you use the DLL built from this repo.

### What was added

| Item | Description |
|------|-------------|
| `Resources/Bango Cat/mode/standard_azerty/` | New mode folder (copy of `standard/` with assets) |
| `standard_azerty/config.json` | Same as standard except **KeyUse** uses AZERTY keys: `["1","2","3","4","5","6","7","a","e","r","space","q","d","s","z"]` |
| `mode/config.json` | **ModelPath** updated to include `"standard_azerty"` so the mode appears in OBS |
| `View.cpp` / `View.hpp` | Plugin now uses **obs_module_file()** so config and assets load from `data/obs-plugins/bongobs-cat/Bango Cat/` (all 6 modes appear when using the DLL built from this repo) |

### Installation

1. Download the latest **[Bango.Cat.AZERTY.zip](https://github.com/Eclipes2/Bongobs-Cat-Plugin-Azerty/releases)** from Releases.  
   The zip is built for **OBS 32.0.4** (64-bit). If you use another OBS version and the plugin fails to load, see "Build the plugin for OBS 32.0.4" below.
2. **Extract the zip into your OBS installation folder** (the folder where **obs64.exe** is). The zip contains `obs-plugins`, `data`, and `bin` — let them merge with the existing OBS folders.
3. Open OBS, add the **Bongo Cat** source, and in **Mode** choose **standard_azerty** for AZERTY keyboards.

The zip is **self-contained**: it bundles the DLLs the plugin needs (including from OBS’s `bin\64bit`), so you don’t need to run any fix script. Just unzip and use.

### Building the release zip (maintainers)

Build the plugin inside the OBS tree (e.g. OBS 32.0.4), then run:

```powershell
.\scripts\build-release-zip.ps1 -ObsRundir "C:\path\to\obs-studio\build_x64\rundir\Release" -RepoPath "C:\path\to\Bongobs-Cat-Plugin-Azerty"
```

This creates **Bango.Cat.AZERTY.zip** at the repo root. Upload it to GitHub Releases.

### Build the plugin for OBS 32.0.4 (or your OBS version)

If the pre-built zip was compiled with a different OBS version (e.g. libobs 32.1) and your OBS is **32.0.4**, build the plugin from source against OBS 32.0.4:

**Prerequisites:** [Visual Studio 2022](https://visualstudio.microsoft.com/) (C++ desktop), [CMake](https://cmake.org/) 3.28+, [Git](https://gitforwindows.org/).

1. **Clone OBS Studio and switch to version 32.0.4**
   ```powershell
   git clone --recursive https://github.com/obsproject/obs-studio.git
   cd obs-studio
   git checkout 32.0.4
   git submodule update --init --recursive
   ```

2. **Add the Bongo Cat AZERTY plugin into the OBS plugins folder**
   - Copy the **entire content** of this repo (Bongobs-Cat-Plugin-Azerty) into `obs-studio\plugins\bongobs-cat\` so that `obs-studio\plugins\bongobs-cat\CMakeLists.txt` exists (and `vtuber_plugin.cpp`, `data\`, etc.).

3. **Register the plugin in OBS build**
   - Open `obs-studio\plugins\CMakeLists.txt` and add this line (e.g. in alphabetical order with the other `add_obs_plugin` / `add_subdirectory` calls, e.g. after `add_obs_plugin(aja ...)`):
   ```cmake
   add_subdirectory(bongobs-cat)
   ```

4. **Configure and build OBS (64-bit)**
   ```powershell
   cmake --preset windows-x64
   cmake --build build_x64 --config Release
   ```
   Or open `build_x64\obs-studio.sln` in Visual Studio, select **Release | x64**, and build the solution.

5. **Install the plugin into your existing OBS 32.0.4**
   - Either create a zip and extract it into your OBS folder:
     ```powershell
     .\scripts\build-release-zip.ps1 -ObsRundir "C:\path\to\obs-studio\build_x64\rundir\Release" -RepoPath "C:\path\to\Bongobs-Cat-Plugin-Azerty"
     ```
     Then extract **Bango.Cat.AZERTY.zip** into `C:\Program Files\obs-studio` (merge `obs-plugins` and `data`).
   - Or copy manually from the build output into your OBS install:
     - From `build_x64\rundir\Release\bin\64bit\obs-plugins\` copy **bongobs-cat.dll** (and **Live2DCubismCore.dll** from this repo: `CubismSdk\Core\dll\windows\x86_64\Live2DCubismCore.dll`) to `C:\Program Files\obs-studio\obs-plugins\64bit\`.
     - From this repo copy `release\data\obs-plugins\bongobs-cat\` to `C:\Program Files\obs-studio\data\obs-plugins\bongobs-cat\`.
   - If the plugin still fails to load with error 126, run the fix script as Administrator (see "If the plugin doesn't load" below).

Restart OBS; the Bongo Cat source should load without the "compiled with newer libobs" error.

### If the plugin doesn’t load

- **"Plugin compiled with newer libobs" (OBS log)** — If the OBS log (Help → Log Files → View Current Log) says the module was *compiled with newer libobs 32.1* (or another version), OBS will not load it. **Fix:** Rebuild the plugin inside the **same OBS source tree / version** as your installed OBS, or use a pre-built zip built for your OBS version. Error 127 = same cause; Error 193 = wrong architecture (use 64-bit plugin for 64-bit OBS).
- Extract the zip so that **obs-plugins** and **data** are directly inside the OBS folder (where **obs64.exe** is), not in a subfolder.
- Use **64-bit OBS** and install [VC++ 2015–2022 x64](https://aka.ms/vs/17/release/vc_redist.x64.exe) if needed.
- If you use an **older zip** (without bundled DLLs) or OBS still reports a load error, run the fix script **as Administrator**. It copies **obs.dll**, the VC++ runtime DLLs, and **all DLLs from OBS’s bin\64bit folder** next to the plugin:
  ```powershell
  powershell -ExecutionPolicy Bypass -File "path\to\scripts\fix-obs-plugin-load.ps1" -ObsPath "C:\Program Files\obs-studio"
  ```
  If OBS shows **"bongobs-cat" twice** or error 126 persists after the fix, run with **-UseBin64Only** so the plugin is only loaded from `bin\64bit\obs-plugins\64bit`.
  If after **-UseBin64Only** the **Bongo Cat** source no longer appears in the list, run with **-RestoreToRoot** so OBS finds it again (and the script re-copies dependencies to the root plugin folder):
  ```powershell
  powershell -ExecutionPolicy Bypass -File "path\to\scripts\fix-obs-plugin-load.ps1" -ObsPath "C:\Program Files\obs-studio" -RestoreToRoot
  ```

### Getting more details about the failure

To see **why** the plugin fails to load (beyond the OBS dialog):

1. **Diagnostic script** (Windows error code + missing DLLs): run from the repo or any folder, then open the report file:
   ```powershell
  powershell -ExecutionPolicy Bypass -File "path\to\scripts\diagnose-plugin-load.ps1" -ObsPath "C:\Program Files\obs-studio" -SimulateOBS -ReportPath "diagnose-report.txt"
   ```
   - **Error 126** = a dependency DLL is missing next to the plugin; the report lists which. Fix: run `fix-obs-plugin-load.ps1` as Administrator.
   - **Error 127** = OBS/plugin version mismatch; rebuild the plugin with your OBS version.
   - **Error 193** = 32-bit DLL with 64-bit OBS (or the reverse); use the correct build.

2. **OBS log**: in OBS go to **Help → Log Files → View Current Log**, or open the folder **%APPDATA%\obs-studio**. Search for **bongobs-cat** or **LoadLibrary**. If you see *"Module '...bongobs-cat.dll' compiled with newer libobs 32.1"*, the fix is to **rebuild the plugin** with your installed OBS version (see "If the plugin doesn't load" above).

---

**Upstream:** [Bongobs-Cat-Plugin](https://github.com/a1928370421/Bongobs-Cat-Plugin) — Bongo Cat Live2D overlay for OBS (OBS Studio 25.0.0+). This fork adds the **standard_azerty** mode for AZERTY keyboards.
