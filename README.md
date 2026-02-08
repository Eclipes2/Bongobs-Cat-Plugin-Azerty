# Bongobs Cat OBS Plugin

## AZERTY support (this fork)

This fork adds **native AZERTY keyboard support** to the Bongo Cat OBS plugin, so that keys A, Z, Q, W, etc. on an AZERTY layout drive the correct actions and visuals without any code changes.

### How it works

- The plugin already supports multiple **modes** (standard, keyboard, feixue, etc.). Each mode has a `config.json` that defines which key names trigger which visual slots (keyboard and hand images).
- The default **standard** mode uses **QWERTY** key names: `q`, `e`, `r`, `space`, `a`, `d`, `s`, `w` for the letter keys. On an AZERTY keyboard, the same physical keys send `a`, `e`, `r`, `space`, `q`, `d`, `s`, `z` — so the overlay and actions were misaligned.
- This fork introduces a separate mode **standard_azerty**: a copy of the standard mode where **KeyUse** in `config.json` is set to the key names that AZERTY keyboards actually send. No C++ or plugin logic is modified; the plugin simply reads the mode config and reacts to the key names we define.

### What was added

| Item | Description |
|------|-------------|
| `Resources/Bango Cat/mode/standard_azerty/` | New mode folder (copy of `standard/` with assets) |
| `standard_azerty/config.json` | Same as standard except **KeyUse** uses AZERTY keys: `["1","2","3","4","5","6","7","a","e","r","space","q","d","s","z"]` |
| `mode/config.json` | **ModelPath** updated to include `"standard_azerty"` so the mode appears in OBS |

### How to use

1. Build or install the plugin as usual (same as upstream Bongobs Cat).
2. In OBS, add the **Bongo Cat** source and open its **Properties**.
3. In **Mode**, select **standard_azerty** instead of **standard**.
4. The cat will now respond correctly to A, Z, Q, W, and the other keys on an AZERTY keyboard.

Optional: to show AZERTY labels on the on-screen keyboard, you can replace the PNGs in `mode/standard_azerty/keyboard/` (and optionally `lefthand/`) with versions that display A, Z, E, R, etc. The behaviour is already correct via **KeyUse**; custom images are only for visual labels.

---

# Bongobs Cat OBS Plugin (upstream)
 Obs Live2d 插件
 Bongo cat overlay for OBS plugin. This plugin is based on the built in Live2d CubismNativeFrameWork & Opengl. 
# 支持
* 支持 OBS Studio version : 25.0.0+
# Support
* Support OBS Studio version** : 25.0.0+
# 如何使用
* 下载 [Bongo.Cat.zip](https://github.com/a1928370421/Bongobs-Cat-Plugin/releases/download/0.1.1/Bango.Cat.zip)
* 解压缩文件到OBS根目录
# How to use
* Download [Bongo.Cat.zip](https://github.com/a1928370421/Bongobs-Cat-Plugin/releases/download/0.1.1/Bango.Cat.zip)
* Unzip file to OBS root direction
# Bongo cat
![](https://github.com/a1928370421/Bongobs-Cat-Plugin/blob/master/Resources/Bango%20Cat/ezgif-2-81825e3faab3.gif)
