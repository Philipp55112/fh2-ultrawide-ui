# FH2 Ultrawide UI for Azimuth

A true ultrawide UI modification for **Forza Horizon 2** and **Forza Horizon 2 Presents Fast & Furious**, running through **Azimuth 0.9.10**.

The goal is simple: make the HUD use the full width of your ultrawide display while keeping menus, dialogs, videos and loading screens in their original, undistorted 16:9 format.

The project has been developed and tested at **3440×1440 (21:9)**. Other ultrawide resolutions, including 2560×1080, 3840×1600 and 32:9, are calculated automatically but have not yet been tested. Feedback and test results are welcome!

## Features

| UI element | Result |
|---|---|
| Speedometer, minimap, race progress and button prompts | Positioned for the full ultrawide width |
| Car name and class, gamertag and credits | Moved towards the screen edges |
| Pause menu, car selection, options and car meet menus | Centred 16:9 layout, undistorted |
| Intro videos, loading screens and fast-travel videos | Preserved in 16:9 with black bars instead of stretching |
| Checkpoints, event markers and "Press A" prompts | Corrected for the new UI centre |
| Nameplates, event titles and post-race results | Repositioned for ultrawide |
| Rewind text, photo mode panels and waiting spinners | Adjusted for the wider UI canvas |
| Car meet player list and vehicle information panels | Repositioned where appropriate |
| FH2 Extra Options 0.2.98 | Optional compatibility adjustment supported |
| Fast-travel loading screens | Adds black side bars around the original 16:9 loading video to hide the surrounding world while it loads during fast travel |

## Tested configurations

### Forza Horizon 2

| Component | Version / setting |
|---|---|
| Game | Forza Horizon 2 — Xbox One version 1.0.0.64 |
| Package identity | `Anthem_1.0.0.64_x64__8wekyb3d8bbwe` |
| Wrapper | Azimuth 0.9.10 |
| Tested resolution | 3440×1440 (21:9) |
| Modified XAML files | 50 |

### Forza Horizon 2 Presents Fast & Furious

| Component | Version / setting |
|---|---|
| Game | Forza Horizon 2 Presents Fast & Furious |
| Package identity | `Spire_1.0.0.6_x64__8wekyb3d8bbwe` |
| Tested resolution | 3440×1440 (21:9) |
| Modified XAML files | 52 |
| Compatibility | Tested successfully |

Both games have been tested with the modification.

## Requirements

- Windows 10 or Windows 11
- Azimuth 0.9.10 with the **original `azimuth.exe`**
- Forza Horizon 2, Xbox One version **1.0.0.64**, and/or Forza Horizon 2 Presents Fast & Furious, version **1.0.0.6**
- The original `Mount\media\UI.zip` and matching `zipmanifest.xml` for the selected game
- Optional: FH2 Extra Options **0.2.98**

Each game uses its own Azimuth directory. Run the installer separately for each installation.

The installer verifies supported files using SHA-256 hashes. If a required file does not match the expected version, installation is aborted before changes are applied.

## Installation

1. Download and extract the release package to a folder of your choice.
2. Optionally place the installer folder inside your Azimuth directory for automatic detection.
3. Run `Install.bat`.
4. If necessary, provide the Azimuth directory when prompted.
5. Confirm the detected game and display resolution. The installer can detect your monitor resolution automatically.
6. Answer the configuration prompts and review the final summary.
7. Confirm the installation.
8. Start the game using `azimuth.exe` as usual.

If the installation directory requires elevated permissions, Windows may request administrator approval.

### What the installer does

- Verifies the expected Azimuth and game UI files before modifying them.
- Creates backups under `<Azimuth folder>\FH2_Ultrawide_backup\`.
- Patches three UI-related constants in `azimuth.exe`: the UI width and two clipping limits.
- Rebuilds `Mount\media\UI.zip` using the game's required archive layout.
- Modifies 49 XAML files for Forza Horizon 2 or 50 for Fast & Furious.
- Updates `zipmanifest.xml` to match the rebuilt archive.
- Optionally adjusts the expected Azimuth executable hash for FH2 Extra Options 0.2.98.
- Backs up conflicting files in `Mount\mediaoverride\UI\` before moving them out of the way.

The original game executable is not modified.

### Uninstallation

Run `Uninstall.bat` and provide the Azimuth directory if prompted.

The uninstaller restores the original files from the backup, including any media-override files moved by the installer. It then verifies that the original `azimuth.exe` has been restored.

Keep your backups until you have confirmed that everything works correctly.

### Changing resolution

Uninstall the modification first, then run the installer again with the new resolution.

### Command-line usage

```powershell
powershell -ExecutionPolicy Bypass -File FH2_Ultrawide.ps1 [-AzimuthDir <path>] [-GameDir <path>] [-Width 3440 -Height 1440] [-NoExtraOptions] [-Yes] [-Uninstall]
```

- `-AzimuthDir`: Specify the Azimuth directory.
- `-GameDir`: Specify the game directory.
- `-Width` / `-Height`: Specify the target resolution.
- `-NoExtraOptions`: Skip the optional Extra Options compatibility adjustment.
- `-Yes`: Run without interactive confirmation prompts.
- `-Uninstall`: Restore the original files.

## No game files included

The installer package contains **no original game files, Azimuth binaries or FH2 Extra Options files**.

It contains the installer, patch data, documentation and licensing information. The installer applies the changes to the user's own files after verifying their hashes.

## How it works

### Why the UI was restricted to 16:9

Azimuth renders the game at the selected ultrawide resolution but originally keeps the UI at 1920×1080 and clips content outside the central 16:9 region.

The game's AVUI interface system also restricts drawing to the defined UI width. Moving elements towards the edges alone therefore causes them to be clipped.

### Azimuth executable patch

The installer patches three UI-related constants:

- **UI width:** Calculated as `1080 × aspect ratio`. At 3440×1440, this results in a width of 2580.
- **Clipping limits:** Two original 16:9-related limits are adjusted to accommodate ultrawide aspect ratios.

The clipping values are calculated according to the target aspect ratio, with additional allowance for very wide displays.

The game executable itself remains untouched.

### UI archive modifications

The installer rebuilds the game's `UI.zip` with the required custom archive layout.

- `Global_Sizes.xaml` defines the wider scene canvas.
- A centred 1920-wide content area preserves the original 16:9 menu layout.
- HUD elements use the wider canvas to reach the screen edges.
- Videos and loading backgrounds remain centred at 1920 pixels wide.
- World markers, nameplates, event titles and result overlays are repositioned to compensate for the changed UI centre.
- Additional panels, prompts and overlays are adjusted where necessary.

Fast-travel loading screen masking

- Adds black side bars around the original 16:9 loading video during fast travel.
- Hides the surrounding world while the destination loads outside the original 16:9 video area.
- Keeps the loading transition visually consistent on ultrawide displays.

The installer applies 49 XAML modifications to Forza Horizon 2 and 50 to Fast & Furious.

### Why a normal ZIP tool cannot be used

The game's UI archive uses a custom layout. A central-directory extra field (`0x1123`) stores absolute data offsets, while `zipmanifest.xml` records the central-directory offset and size.

Repacking the archive with an ordinary ZIP tool can break these offsets and cause the game to display a black screen.

The installer rebuilds the archive using the expected layout and updates the matching manifest.

## Known limitations

- **3440×1440 is the tested resolution.** Other ultrawide resolutions are calculated automatically but have not yet been verified.
- The supported game configurations are Azimuth 0.9.10 with Forza Horizon 2 1.0.0.64 or Fast & Furious 1.0.0.6.
- Each game requires its own Azimuth directory and a separate installer run.
- Only FH2 Extra Options 0.2.98 is supported by the optional compatibility adjustment. Other versions are left unchanged.
- Other UI modifications, edited `UI.zip` archives and conflicting files under `Mount\mediaoverride\UI\` may cause compatibility issues.
- 16:9 and 16:10 resolutions are not supported by the installer.

Please report issues and results for other ultrawide resolutions through GitHub Issues.

## Credits & development tools

- **Azimuth contributors** — for making these games playable on PC.
- **FH2 Extra Options author** — for the additional modding functionality.
- **Claude (Anthropic)** — used as an AI-assisted research and development tool for technical analysis, XAML changes, troubleshooting and documentation.

The modifications were validated through in-game testing and iterative adjustments.

## License

The installer script and patch data are licensed under the MIT License. See [`LICENSE`](LICENSE) for details.

Forza Horizon 2 and Forza Horizon 2 Presents Fast & Furious are © their respective rights holders. Azimuth and FH2 Extra Options remain the property of their respective authors and are subject to their own licensing terms.

This is an unofficial community project and is not affiliated with or endorsed by Microsoft, Xbox, Playground Games or the Azimuth project.
