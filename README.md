# Forza 21:9 Ultrawide Patch

**True 21:9 ultrawide UI support for Forza Horizon 2, Forza Horizon 2 Presents Fast & Furious, and Forza Motorsport 5 running on PC through Azimuth.**

See [CHANGELOG.md](CHANGELOG.md) for the complete version history.

The Forza 21:9 Ultrawide Patch adjusts the games' user interfaces for ultrawide displays, providing a wider HUD while keeping menus and other 16:9 content properly centered.

The project currently supports **Forza Horizon 2**, **Forza Horizon 2 Presents Fast & Furious**, and **Forza Motorsport 5** using a single Azimuth 1.0.2 or 1.0.3 installation.

Support for **Forza Horizon 3** and **Forza Motorsport 6** is in development.

## Features

| Feature                            | Description                                                                                                                        |
| ---------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------- |
| Ultrawide HUD                      | Repositions UI elements to make better use of 21:9 displays                                                                        |
| Centered menus                     | Keeps menus and other interface elements centered instead of stretching the entire UI across the screen                            |
| Per-game configuration             | Enables or disables the patch individually for each supported title                                                                |
| Fast-travel loading screen masking | Adds black side bars around the original 16:9 loading video to hide the surrounding world while it loads during fast travel in FH2 |
| FM5 UI corrections                 | Fixes UI clipping, scaling, screen-copy effects and other ultrawide-related issues                                                 |
| Original executable preserved      | Keeps `azimuth.exe` unmodified                                                                                                     |
| Automatic backups                  | Saves original files before applying modifications                                                                                 |
| Installer and uninstaller          | Supports installation, updates and removal of the patch                                                                            |

## Supported Games

| Game                                    | Status          | Resolution support             |
| --------------------------------------- | --------------- | ------------------------------ |
| Forza Horizon 2                         | Supported       | Ultrawide resolutions          |
| Forza Horizon 2 Presents Fast & Furious | Supported       | Ultrawide resolutions          |
| Forza Motorsport 5                      | Initial support | Currently limited to 3440×1440 |
| Forza Horizon 3                         | In development  | Coming soon                    |
| Forza Motorsport 6                      | In development  | Coming soon                    |

FH2 and Fast & Furious adapt to different ultrawide resolutions. FM5 currently has a dedicated fix for 3440×1440, with broader resolution support in development.

## Requirements

- Windows PC
- Azimuth **1.0.2 or 1.0.3**
- A compatible installation of the supported game
- An ultrawide display for the intended 21:9 experience

## Installation

Two installation packages are available.

### Option 1: Standalone EXE installer

Run `Forza21x9_Setup.exe`.

The installer provides a graphical interface to:

- Select the Azimuth installation folder.
- Configure the target resolution.
- Enable or disable the patch for individual games.
- Install or update the patch.
- Uninstall all patch modifications.

The installer creates backups of original files before applying changes.

### Option 2: Classic ZIP package

The classic ZIP package contains the batch files and supporting scripts for the traditional installation method.

1. Extract the ZIP package.
2. Follow the included instructions.
3. Run the appropriate batch file for the operation you want to perform.
4. Keep the generated backups until you have verified that everything works correctly.

Always read the instructions included with the package before installing or updating.

## Configuration

The patch uses `azimuth_21x9.ini` to configure the UI width and enable or disable support for individual titles.

Example:

```ini
[ui]
width=2580

[titles]
fh2=1
fnf=1
fm5=1
fh3=0
fm6=0
```

The title identifiers above illustrate the configuration concept. Use the identifiers and options provided by the actual installer and package version.

The default UI width of `2580` corresponds to a 21:9 layout based on a 1920-pixel-wide 16:9 reference UI.

Unknown or disabled titles retain their original behavior.

## How It Works

### In-memory Azimuth patching

Unlike approaches that modify the Azimuth executable directly, this patch leaves `azimuth.exe` unchanged.

A `dinput8.dll` proxy is placed next to `azimuth.exe`. Since Azimuth imports `DINPUT8.dll`, the proxy can load automatically, forward `DirectInput8Create` to the original Windows system DLL and apply the necessary patches in memory.

The patch identifies the active game using its executable image metadata, with a configuration fallback. It then enables the appropriate UI modifications for that title.

This approach preserves compatibility with hash checks used by Azimuth and FH2 Extra Options.

### UI layout modifications

The patch modifies the games' XAML-based UI layouts inside `Mount\media\UI.zip`.

The modified archives are rebuilt from the original UI files using predefined operations that verify the expected original data before replacing it.

Forza's custom ZIP layout uses an additional central-directory field (`0x1123`) containing absolute data offsets. The patch preserves this structure and updates the relevant `zipmanifest.xml` directory information.

### Forza Motorsport 5 fixes

FM5 requires additional corrections beyond the standard UI-width changes, including:

- Adjustments to the UI root size.
- Corrections to UI clipping and aspect handling.
- Changes to the screen-copy helpers used for effects such as glass backgrounds and blur.
- Adjustments to UI frame dimensions.
- An additional effect-pool correction.

These modifications are applied in memory and only when FM5 support is enabled.

The current FM5 implementation is limited to 3440×1440. The intro videos and map loading screen remain in their original 16:9 format.

## Backups and Uninstallation

The installer backs up original files to:

`<Azimuth folder>\Forza21x9_backup\`

The backup includes the original files required to restore the installation.

Use the included uninstaller to remove the patch and restore the backed-up files. Do not delete the backup folder until you have confirmed that the original installation has been restored successfully.

The patch should be configured separately for each Azimuth installation you use.

## Known Issues and Limitations

### Forza Motorsport 5

- The current ultrawide UI fix supports **3440×1440 only**.
- Frame-rate drops have been observed in the garage and pre-race screen.
- The cause of the performance drops is still under investigation. It is not yet clear whether they are caused by the patch, Azimuth or an interaction between the two.
- The intro videos and map loading screen remain 16:9.

### General

- The patch is intended for compatible Azimuth installations and game versions.
- Modified UI archives must preserve the game's custom ZIP structure. Repacking them with ordinary ZIP tools may break the game.
- Back up your files before making manual changes.

## Roadmap

Planned improvements include:

- Forza Horizon 3 support.
- Forza Motorsport 6 support.
- Additional FM5 ultrawide resolutions.
- Further compatibility and performance testing.
- A shareable build that does not bundle original game files.

## Credits

- **Azimuth project** — for making it possible to run these games on PC.
- **Claude (Anthropic)** — assistance with research, development and implementation.
- The community — for feedback, testing and continued interest in preserving these games.

## Disclaimer

This is an unofficial community project. It is not affiliated with or endorsed by Microsoft, Xbox, Playground Games or Turn 10 Studios.

Use the patch at your own risk. Always keep backups of your original files.

## Project and Downloads

GitHub repository:

[https://github.com/Philipp55112/fh2-ultrawide-ui](https://github.com/Philipp55112/fh2-ultrawide-ui)

Bug reports, feedback and testing at additional ultrawide resolutions are welcome!
