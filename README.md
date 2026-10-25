# FH2 Ultrawide UI for Azimuth

A real ultrawide UI for **Forza Horizon 2** and **Forza Horizon 2 Presents Fast & Furious** running through **Azimuth 0.9.10**.

The HUD moves to the edges of your screen: speedometer, minimap, race progress, button prompts, car name and class, gamertag and credits. Menus, dialogs, videos and loading screens stay unstretched in 16:9.

Developed and tested on **3440×1440 (21:9)**. Other ultrawide resolutions (2560×1080, 3840×1600, 32:9, …) are calculated automatically but have not been tested yet. Feedback is welcome.

## What you get

| Element | Result |
|---|---|
| Speedometer, minimap, race info, button bars, car name/class, gamertag/credits | at the real screen edges |
| Pause menu, car select, options, car meet menu, pre-race screens | centred 16:9, undistorted |
| Intro video, loading screens, fast-travel video | 16:9 with black bars instead of stretched; their text stays inside 16:9 |
| World markers (checkpoints, event markers, "press A"), name tags, event titles, post-race results | at their correct positions |
| Rewind text, photo mode panel, wait spinners, car meet player list, car stats and info panels in car select / car meet | at the screen edges |
| FH2 Extra Options 0.2.98 | keeps working (the installer can adjust it, optional) |

## Requirements

- Forza Horizon 2, Xbox One build **1.0.0.64**, or FH2 Presents Fast & Furious **1.0.0.6**, with the **original** `Mount\media\UI.zip`
- **Azimuth 0.9.10** (the original `azimuth.exe`)
- Windows 10/11 (the installer uses the built-in PowerShell)
- Optional: FH2 Extra Options **0.2.98**

The installer checks every file by its SHA-256 hash. If something does not match, it refuses and changes nothing.

## Install

1. Extract this folder anywhere. Putting it inside your Azimuth folder means it is found automatically.
2. Run **`Install.bat`**.
3. Confirm your screen resolution (detected automatically) and answer the questions.
4. Start the game with `azimuth.exe` as usual.

The installer will:

- back up the originals to `<Azimuth folder>\FH2_Ultrawide_backup\`:
  - `azimuth.exe`, `winmm.dll`, `UI.zip`, `zipmanifest.xml`
- patch 3 constants in `azimuth.exe`: the UI width and two clip-plane limits
- rebuild `Mount\media\UI.zip`, changing 49 UI files (50 for Fast & Furious), and update `zipmanifest.xml`
- optionally update FH2 Extra Options' expected `azimuth.exe` hash, so it does not disable itself
- move files in `Mount\mediaoverride\UI\` that would override the mod into the backup folder

**Uninstall:** run **`Uninstall.bat`**. Everything is restored from the backup.

**Changed resolution?** Uninstall, then install again.

Command-line options:

```
powershell -ExecutionPolicy Bypass -File FH2_Ultrawide.ps1 [-AzimuthDir <path>] [-GameDir <path>] [-Width 3440 -Height 1440] [-NoExtraOptions] [-Yes] [-Uninstall]
```

## No game files included

This package contains **no** game files, no Azimuth binaries and no Extra Options files. It only has a script and a list of small edits, which are applied to **your own** files after their hashes have been verified.

## How it works

**Why the UI was stuck in 16:9.** Azimuth renders the game at 21:9 but keeps the UI at 1920×1080 and clips everything outside the 16:9 centre. The UI engine (AVUI, a WPF-like XAML framework) also does not draw elements outside its UI width. So anything moved towards the edge was cut off.

**`azimuth.exe` patch (3 constants):**
- The UI width is set to `1080 × aspect`. For example, 3440×1440 gives 2580.
- The two 16/9 clip-plane constants are raised to 2.45. For very wide screens they are set slightly above the aspect ratio instead.
- The game executable itself is untouched (Azimuth verifies its hash).

**`UI.zip` (49 XAML files):**
- `Global_Sizes.xaml`: the scene width is set to the new UI width. The scene padding container is kept 1920 wide and centred, so menu content stays 16:9.
- Pages with a hard-coded width of 1920 (pause menu, options, …) are set to the full width.
- Videos and loading backgrounds are 1920 wide and centred on black.
- **3D elements** (world markers, name tags, event titles, post-race results) are centred by the game on the middle of the UI, which moved from 960 to `W/2`. Their pages get a width of 1920 again plus a `+ (W − 1920) / 2` translation. For 21:9 that is +330.
- Edge elements (rewind text, photo mode panel, spinners) use the full width.

**UI.zip format.** FH2's `UI.zip` has a custom layout: a central-directory extra field `0x1123` stores the absolute data offset of each file. `zipmanifest.xml` stores the offset and size of the central directory. Repacking with a normal zip tool causes a black screen. The installer rebuilds the archive in exactly that layout and updates the manifest.

## Known limitations

- Only tested on 3440×1440. Please report results for other resolutions.
- Only Azimuth 0.9.10 with FH2 1.0.0.64 or FH2 Fast & Furious 1.0.0.6 is supported. Each game has its own Azimuth folder, so run the installer once per game.
- Only Extra Options 0.2.98 can be adjusted; other versions stay untouched and will disable themselves with the patched `azimuth.exe`.
- If you use other UI mods (`UI.zip` edits or `mediaoverride\UI`), they will conflict.

## Credits

- The Azimuth team, for making FH2 playable on PC.
- The author of FH2 Extra Options.
- Reverse engineering, patches and installer: made with Claude (Anthropic).

## License

The installer script and patch data are MIT-licensed (see `LICENSE`). Forza Horizon 2 is © Microsoft / Playground Games. Azimuth and FH2 Extra Options belong to their respective authors.
