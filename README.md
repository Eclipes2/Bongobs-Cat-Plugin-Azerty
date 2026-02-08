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

### How to use

1. Download the latest release from [Releases](https://github.com/Eclipes2/Bongobs-Cat-Plugin-Azerty/releases) (get **Bango.Cat.AZERTY.zip**). Unzip to the **OBS installation root** (the folder where **obs64.exe** is), so that `obs-plugins/64bit/` and `data/obs-plugins/bongobs-cat/` end up inside that folder.
2. In OBS, add the **Bongo Cat** source and open its **Properties**.
3. In **Mode**, select **standard_azerty** (the zip includes this mode for AZERTY keyboards).
4. The cat will now respond correctly to A, Z, Q, W, and the other keys on an AZERTY keyboard.

Optional: to show AZERTY labels on the on-screen keyboard, you can replace the PNGs in `mode/standard_azerty/keyboard/` (and optionally `lefthand/`) with versions that display A, Z, E, R, etc. The behaviour is already correct via **KeyUse**; custom images are only for visual labels.

### Building the plugin

To get a DLL that loads all 6 modes (including **standard_azerty**) from the plugin data folder, build this project with the OBS build environment (see [OBS build instructions for Windows](https://obsproject.com/wiki/Build-Instructions-For-Windows)). The plugin uses CMake and `install_obs_plugin_with_data`; it must be built as an OBS plugin (with libobs). After building, copy **bongobs-cat.dll** into `release/obs-plugins/64bit/`. Also copy **Live2DCubismCore.dll** from `CubismSdk/Core/dll/windows/x86_64/` into `release/obs-plugins/64bit/`. Then create **Bango.Cat.AZERTY.zip** from `release/data` and `release/obs-plugins` (these two folders at the root of the zip). The plugin loads config and assets from `data/obs-plugins/bongobs-cat/Bango Cat/` via `obs_module_file()`.

### If the plugin fails to load

- **Extract to the correct folder:** Unzip so that `obs-plugins` and `data` are **directly** inside the OBS installation directory (where **obs64.exe** is), not in a subfolder.
- **64-bit OBS only:** Use OBS Studio 64-bit; the plugin in `obs-plugins/64bit/` is for 64-bit only.
- **Visual C++ Redistributable:** Install [VC++ 2015–2022 x64](https://aka.ms/vs/17/release/vc_redist.x64.exe). Required for the plugin to load.
- **OBS version mismatch (most common):** The pre-built **bongobs-cat.dll** was built against one specific OBS version. If your OBS is newer or older (e.g. 28, 30, 31), the DLL may fail to load. **Solution:** rebuild the plugin from this repo using the same OBS version as your installation (see [OBS build instructions](https://obsproject.com/wiki/Build-Instructions-For-Windows)), then replace `obs-plugins/64bit/bongobs-cat.dll` with your build.
- **Check the exact error:** Run OBS from a command prompt and check the console, or run the diagnostic script: from your OBS folder, `powershell -ExecutionPolicy Bypass -File path\to\scripts\diagnose-plugin-load.ps1` (or copy the script to the OBS folder and run it there). Error code **127** = OBS version mismatch → rebuild the plugin with your OBS version.

---

**Upstream:** [Bongobs-Cat-Plugin](https://github.com/a1928370421/Bongobs-Cat-Plugin) — Bongo Cat Live2D overlay for OBS (OBS Studio 25.0.0+). This fork adds the **standard_azerty** mode for AZERTY keyboards.
