# OBS folder layout and plugin zip layouts

Used to debug plugin load issues. The repo contains:
- **backup/** — Snapshot of OBS: clean install (bin, data, obs-plugins) **and** the extracted **original/source** Bongo Cat zip in `backup/Bango Cat/`.
- **backup/Bango Cat/** — Contents of the **original** Bongo.Cat zip (upstream repo, not this fork). Use it to compare with our fork’s layout.

## Clean OBS install layout (no plugin)

| Path | Contents |
|------|----------|
| `bin/64bit/` | obs64.exe, **obs.dll**, Qt6Core.dll, Qt6Gui.dll, libobs-*.dll, avcodec, etc. **No** `obs-plugins` subfolder here. |
| `obs-plugins/64bit/` | All plugin DLLs (obs-browser, obs-ffmpeg, win-capture, …). **No** obs.dll here; they rely on `bin/64bit` for core deps. |
| `data/obs-plugins/` | Per-plugin data (frontend-tools, obs-filters, win-capture, win-dshow, etc.). |

When OBS loads a plugin from `obs-plugins/64bit/`, Windows usually searches for dependencies in:
1. Directory of the executable → `bin/64bit` (obs64.exe)
2. Directory of the plugin DLL → `obs-plugins/64bit`
3. System directories, PATH

So in theory **obs.dll** is found in `bin/64bit`. Error 126 can still happen if:
- OBS (or the system) restricts the loader to the plugin directory only, or
- A dependency (e.g. VC++ runtime, or a DLL only in `bin/64bit`) is not found on that path.

## What the fix script does

1. Copies **obs.dll** and VC++ runtime DLLs next to the plugin in `obs-plugins/64bit/`.
2. Copies **all DLLs** from `bin/64bit/` into `obs-plugins/64bit/` so every dependency is in the plugin folder.
3. Optionally installs the plugin (and same DLLs) into `bin/64bit/obs-plugins/64bit/` so both possible load paths are covered.
4. Copies plugin data to `data/obs-plugins/bongobs-cat/` (and other locations OBS might use).

## Reference: backup contents

- **backup/bin/64bit/**  
  Top-level DLLs: obs.dll, Qt6*.dll, libobs-*.dll, avcodec-61.dll, etc.  
  Subfolders: iconengines, imageformats, platforms, styles (Qt plugins).
- **backup/obs-plugins/64bit/**  
  Plugin DLLs only; no obs.dll. Has platforms/, imageformats/, etc. from the installer.
- **backup/data/obs-plugins/**  
  No `bongobs-cat` folder in a clean install; that is created when you add the plugin and run the fix or extract the zip.

---

## Original (source) Bongo Cat zip layout — `backup/Bango Cat/`

This is what the **upstream** Bongo.Cat zip extracts to (not this fork):

| Path | Contents |
|------|----------|
| `obs-plugins/64bit/` | **bongobs-cat.dll** only (no Live2DCubismCore in this snapshot). |
| `data/obs-plugins/bongobs-cat/` | **locale/** only (en-US.ini, zh-CN.ini). |
| `bin/64bit/Bango Cat/` | **All assets**: `Bango Cat/img/keyboard/`, `img/standard/`, `Bango Cat/Resources/cat/`, `Resources/right hand/`, l2dlogo.png, etc. |

So the **original** plugin expects resources under **bin/64bit/Bango Cat/** (paths relative to the executable or hardcoded). It does **not** use `data/obs-plugins/bongobs-cat/Bango Cat/` with a `mode/config.json` list.

## This fork (AZERTY) zip layout — Bango.Cat.AZERTY.zip

| Path | Contents |
|------|----------|
| `obs-plugins/64bit/` | **bongobs-cat.dll**, **Live2DCubismCore.dll**. |
| `data/obs-plugins/bongobs-cat/` | **locale/** + **Bango Cat/** with **mode/config.json**, **mode/standard_azerty/** (and other modes), **face/**, etc. |

This fork uses **obs_module_file()** so config and assets are loaded from **data/obs-plugins/bongobs-cat/Bango Cat/** (no assets under `bin/64bit/Bango Cat/`). The fix script and dependency copies (obs.dll, bin/64bit DLLs) are the same regardless of which zip you use; only the data layout differs.

## Building the release zip (maintainers)

**build-release-zip.ps1** chooses the plugin data for the zip in this order:

1. **release/data/obs-plugins/bongobs-cat** — If this folder exists in the repo, it is used as-is. That guarantees the zip contains the full set of modes (standard, standard_azerty, keyboard, feixue, bilibiliduo, mania) and the correct layout. Keep this folder in sync with **Resources/Bango Cat/** (or populate it from a known-good install) so the script always produces a zip with all modes.
2. **ObsRundir/data/obs-plugins/bongobs-cat** — If release/ is missing, the script uses the OBS build output data dir.
3. **Fallback** — Repo **data/** (locale) plus **Resources/Bango Cat/** contents copied into **Bango Cat/** (so the zip has `data/obs-plugins/bongobs-cat/Bango Cat/mode/config.json`, not `.../Bango Cat/Bango Cat/mode/...`).
