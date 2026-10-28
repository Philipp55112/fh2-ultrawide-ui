# Forza 21:9 Ultrawide Patch

**True 21:9 ultrawide UI support for Forza Horizon 2, Forza Horizon 2 Presents Fast & Furious, and Forza Motorsport 5 running on PC through Azimuth.**

See [CHANGELOG.md](CHANGELOG.md) for the complete version history.

The Forza 21:9 Ultrawide Patch adapts the games' user interfaces for ultrawide displays, providing a wider HUD while keeping supported menus and other 16:9 content properly centred.

The project supports **Forza Horizon 2**, **Forza Horizon 2 Presents Fast & Furious**, and **Forza Motorsport 5** using Azimuth **1.0.2 or 1.0.3**.

Support for **Forza Horizon 3** and **Forza Motorsport 6** is planned for future releases.

## Features

| Feature | Description |
| --- | --- |
| Ultrawide HUD | Repositions UI elements to make better use of ultrawide displays |
| Resolution-aware UI | Calculates the appropriate UI layout for the selected resolution during installation |
| Centred menus | Keeps supported menus, dialogs, videos and loading screens centred instead of stretching the entire UI |
| Per-game configuration | Enables or disables the patch individually for each supported title |
| FM5 full frame rate | Prevents the game from halving the configured frame rate in the garage and pre-race screens |
| FM5 main menu fixes | Corrects the animated header lines and right-side dot pattern |
| Fast-travel loading screen masking | Adds black side bars around the original 16:9 loading video in FH2 |
| Optional desktop shortcuts | Creates shortcuts that launch individual games directly without opening the Azimuth launcher |
| Original executable preserved | Keeps `azimuth.exe` unmodified |
| Automatic backups | Verifies original files using SHA-256 and backs them up before modification |
| Installer and uninstaller | Supports installation, updates, game selection and restoration of original files |

## Supported Games

| Game | Version | Status | Resolution support |
| --- | --- | --- | --- |
| Forza Horizon 2 | `1.0.0.64` | Supported | Ultrawide resolutions |
| Forza Horizon 2 Presents Fast & Furious | `1.0.0.6` | Supported | Ultrawide resolutions |
| Forza Motorsport 5 | `1.0.0.20` | Supported | Resolution calculated during installation |
| Forza Horizon 3 | — | Planned | Future release |
| Forza Motorsport 6 | — | Planned | Future release |

FH2 and Fast & Furious adapt to different ultrawide resolutions.

For FM5, the UI layout is now generated during installation for the selected resolution instead of being fixed to 3440×1440. Resolutions such as 2560×1080, 3440×1440 and 3840×1600 are supported by the layout calculations. 32:9 is theoretically supported, but resolutions other than 3440×1440 have not all been tested.

## Requirements

- Windows PC
- A compatible installation of a supported game
- Azimuth **1.0.2 or 1.0.3**
- An ultrawide display for the intended 21:9 experience
- Sufficient free disk space for backups and modified UI files

## Installation

Two installation packages are available in the Releases section.

### Option 1: Standalone EXE installer

Run `Forza21x9_Setup.exe`.

The installer allows you to:

- Select the Azimuth installation folder.
- Select the target resolution.
- Enable or disable the patch for each supported game individually.
- Optionally create desktop shortcuts for configured games.
- Install or update the patch.
- Uninstall the patch and restore original files.

The installer verifies the expected original files using SHA-256 and creates backups before applying modifications.

### Option 2: Classic ZIP package

The classic ZIP package contains the English batch installer and uninstaller, along with the required scripts and supporting files.

1. Extract the ZIP package.
2. Run `Install.bat`.
3. Select your Azimuth installation folder using the folder picker.
4. Select your target resolution.
5. Choose whether to install the patch for each supported game.
6. Follow the instructions displayed by the installer.

To remove the patch, run `Uninstall.bat`.

The installer preserves backups so that the original files can be restored. Keep the backup folder until you have verified that the original installation has been restored successfully.

## Optional Desktop Shortcuts

The installer can create desktop shortcuts for each configured game using the corresponding game logo as its icon.

These shortcuts launch the selected game directly without opening the Azimuth launcher. The launch commands use Azimuth's game selection and launcher-skipping arguments.

Examples:

- Forza Horizon 2: `azimuth.exe --game=fh2 --skip-launcher`
- Forza Horizon 2 Presents Fast & Furious: `azimuth.exe --game=fh2-ff --skip-launcher`
- Forza Motorsport 5: `azimuth.exe --game=fm5 --skip-launcher`

The shortcuts are optional and are removed by the uninstaller.

## Configuration

The patch uses `azimuth_21x9.ini` for additional settings.

### Per-game configuration

The installer lets you enable or disable the patch for each supported title individually. Disabled games have their original UI restored.

The following identifiers illustrate the title configuration concept; use the identifiers and options supplied by the actual installer and package version.

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

The UI width shown is an example for a 3440×1440 display, based on the original 1920-pixel-wide 16:9 reference UI. The installer calculates the appropriate layout for the selected resolution.

### Forza Motorsport 5 full frame rate

FM5 normally halves the configured frame rate in the garage and pre-race screens. The patch prevents this behavior so both screens can run at the full configured frame rate.

To disable this correction, set `full_rate=0` under the `[fm5]` section in `azimuth_21x9.ini`:

```ini
[fm5]
full_rate=0
```

Use the configuration file and section supplied with your installed version.

## How It Works

### In-memory Azimuth patching

The patch leaves `azimuth.exe` unchanged.

A `dinput8.dll` proxy is placed alongside `azimuth.exe`. Since Azimuth imports `DINPUT8.dll`, the proxy can load automatically, forward `DirectInput8Create` to the original Windows system DLL, and apply the necessary patches in memory.

The patch identifies the active game and enables the appropriate modifications for that title.

This approach preserves compatibility with Azimuth executable integrity checks and FH2 Extra Options.

### UI layout modifications

The patch modifies the games' XAML-based UI layouts inside `Mount\media\UI.zip`.

The modified archives are rebuilt from the original UI files using predefined operations that verify expected original data before replacing it.

Forza's custom ZIP layout uses an additional central-directory field (`0x1123`) containing absolute data offsets. The patch preserves this structure and updates the relevant `zipmanifest.xml` directory information.

The patch does not include any game files or Azimuth files.

### Forza Motorsport 5 fixes

FM5 requires additional corrections beyond standard UI-width adjustments, including:

- Adjustments to the UI root size.
- Corrections to UI clipping and aspect handling.
- Changes to screen-copy helpers used for effects such as glass backgrounds and blur.
- Adjustments to UI frame dimensions.
- An additional effect-pool correction.
- Corrections to the animated header lines and dot pattern in the main menu.
- A full-frame-rate correction for the garage and pre-race screens.

The UI layout is generated during installation for the selected resolution. Runtime modifications are applied only when FM5 support is enabled.

Intro videos and the map loading screen remain in their original 16:9 format.

## Backups and Uninstallation

The installer backs up original files to:

`<Azimuth folder>\Forza21x9_backup\`

Original files are verified using SHA-256 before modifications are applied. The backup contains the files required to restore the original installation.

Use the included uninstaller to remove the patch and restore the backed-up files. The uninstaller also removes the optional desktop shortcuts created by the installer.

Do not delete the backup folder until you have confirmed that the original installation has been restored successfully.

The patch should be configured separately for each Azimuth installation you use.

## Known Issues and Limitations

### Resolution testing

- **3440×1440 (21:9)** is the primary tested resolution.
- Other resolutions are calculated during installation but have not all been tested.
- 32:9 support is theoretical and has not been confirmed through testing.

### Forza Motorsport 5

- Intro videos and the map loading screen remain in their original 16:9 format.
- Performance and compatibility may vary depending on the game, Azimuth version and configuration.

### General

- The patch is intended for compatible Azimuth installations and game versions.
- Modified UI archives must preserve the game's custom ZIP structure. Repacking them with ordinary ZIP tools may break the game.
- Back up your files before making manual changes.

## Roadmap

Planned improvements include:

- Forza Horizon 3 support.
- Forza Motorsport 6 support.
- Further resolution compatibility testing.
- Additional compatibility improvements and testing.

## Credits

- **Azimuth project** — for making it possible to run these games on PC.
- **Claude (Anthropic)** — assistance with research, development and implementation.
- The community — for feedback, testing and continued interest in preserving these games.

## Disclaimer

This is an unofficial community project. It is not affiliated with or endorsed by Microsoft, Xbox, Playground Games or Turn 10 Studios.

Use the patch at your own risk. Always keep backups of your original files.

## Project and Downloads

GitHub repository:

https://github.com/Philipp55112/fh2-ultrawide-ui

See [CHANGELOG.md](CHANGELOG.md) for the complete version history.

Bug reports, feedback and testing at additional ultrawide resolutions are welcome!
