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
2. **Extract the zip into your OBS installation folder** (the folder where **obs64.exe** is). The zip contains `obs-plugins` and `data` — let them merge with the existing OBS folders.
3. Open OBS, add the **Bongo Cat** source, and in **Mode** choose **standard_azerty** for AZERTY keyboards.

The zip is **self-contained**: it bundles the DLLs the plugin needs (including from OBS’s `bin\64bit`), so you don’t need to run any fix script. Just unzip and use.

### Building the release zip (maintainers)

Build the plugin inside the OBS tree, then run:

```powershell
.\scripts\build-release-zip.ps1 -ObsRundir "C:\path\to\obs-studio\build_x64\rundir\Release" -RepoPath "C:\path\to\Bongobs-Cat-Plugin-Azerty"
```

This creates **Bango.Cat.AZERTY.zip** at the repo root. Upload it to GitHub Releases.

### If the plugin doesn’t load

- Extract the zip so that **obs-plugins** and **data** are directly inside the OBS folder (where **obs64.exe** is), not in a subfolder.
- Use **64-bit OBS** and install [VC++ 2015–2022 x64](https://aka.ms/vs/17/release/vc_redist.x64.exe) if needed.
- If you use an **older zip** (without bundled DLLs) or OBS still reports a load error, run the fix script **as Administrator**. It copies **obs.dll**, the VC++ runtime DLLs, and **all DLLs from OBS’s bin\64bit folder** next to the plugin:
  ```powershell
  powershell -ExecutionPolicy Bypass -File "path\to\scripts\fix-obs-plugin-load.ps1" -ObsPath "C:\Program Files\obs-studio"
  ```

---

**Upstream:** [Bongobs-Cat-Plugin](https://github.com/a1928370421/Bongobs-Cat-Plugin) — Bongo Cat Live2D overlay for OBS (OBS Studio 25.0.0+). This fork adds the **standard_azerty** mode for AZERTY keyboards.
