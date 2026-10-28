# Changelog

All notable changes to the Forza 21:9 Ultrawide Patch are documented here.

## [v1.2.1] — FM5 Vehicle Image Aspect Ratio Fix

### Fixed
- Fixed horizontally stretched vehicle images in the **Car Dealer**, **My Cars**, **Marketplace**, and **livery selection popup** in Forza Motorsport 5.
- Removed the additional width correction from these locations because Azimuth 1.0 already renders the images with the correct aspect ratio.
- Preserved the width correction for vehicle images in **Free Play, multiplayer lobbies, player cards, lobby garage popups, Hopper selection, and profiles**, where the game still renders images too narrow.

### Other Changes
- No other changes compared to v1.2.0.

## [v1.2.0] — Expanded Ultrawide Support & Quality of Life Improvements

### Added
- Added support for **Azimuth 1.0.3**, while maintaining compatibility with Azimuth 1.0.2.
- Added resolution-aware UI layout generation for Forza Motorsport 5 during installation.
- Added optional per-game desktop shortcuts that launch games directly without opening the Azimuth launcher.
- Added game-specific shortcut icons using the corresponding game logos.
- Added an English-language classic ZIP installer with `Install.bat` and `Uninstall.bat`.
- Added folder selection for the Azimuth installation directory.
- Added resolution selection and individual yes/no selection for each supported game in the classic installer.

### Changed
- Expanded FM5 ultrawide UI support beyond the previously fixed 3440×1440 layout.
- FM5 UI layouts are now calculated for the selected resolution during installation, including 2560×1080, 3440×1440 and 3840×1600. 32:9 is theoretically supported but has not been confirmed through testing.
- Improved the installation and uninstallation workflow.
- Continued using a single, unmodified `azimuth.exe`, preserving compatibility with FH2 Extra Options.

### Fixed
- **FM5 garage and pre-race frame rate:** Prevented the game from halving the configured frame rate in the garage and pre-race screens. These screens can now run at the full configured frame rate.
- **FM5 main menu:** Fixed the animated header lines so they extend to the right edge.
- **FM5 main menu:** Corrected the dot pattern positioning so it sits at the right edge, matching the original UI.

### Configuration
- Added the `full_rate` option under the `[fm5]` section in `azimuth_21x9.ini`.
- Set `full_rate=0` to disable the FM5 full-frame-rate correction.

### Compatibility
- Azimuth 1.0.2
- Azimuth 1.0.3

Supported games:
- Forza Horizon 2 — `1.0.0.64`
- Forza Horizon 2 Presents Fast & Furious — `1.0.0.6`
- Forza Motorsport 5 — `1.0.0.20`

### Notes
- 3440×1440 remains the primary tested ultrawide resolution.
- Other FM5 resolutions are calculated during installation but have not all been tested.
- The 32:9 layout is theoretical and remains unverified.
- Forza Horizon 3 and Forza Motorsport 6 are planned for future releases.

---

## [v1.1.0] — Expanded Game Support

### Added
- Added support for **Forza Motorsport 5** (version `1.0.0.20`).
- Added a standalone EXE installer alongside the classic ZIP package with batch scripts.
- Added per-game patch enable/disable support.

### Changed
- Updated compatibility to **Azimuth 1.0.2 and 1.0.3**.
- Introduced runtime in-memory patching through a `dinput8.dll` proxy without modifying `azimuth.exe`.
- Improved UI scaling, aspect ratio handling and clipping fixes.
- Expanded the patch beyond Forza Horizon 2 and Fast & Furious.

### Fixed
- Added additional UI and aspect ratio fixes for Forza Motorsport 5.
- Improved ultrawide UI handling for supported games.

### Known Issues at Release
- The Forza Motorsport 5 UI fix was limited to **3440×1440**.
- Performance drops in the garage and pre-race screens remained unresolved.
- Other ultrawide resolutions had not all been tested.

### Requirements
- Azimuth 1.0.2 or 1.0.3.

Supported games:
- Forza Horizon 2 — `1.0.0.64`
- Forza Horizon 2 Presents Fast & Furious — `1.0.0.6`
- Forza Motorsport 5 — `1.0.0.20`

---

## [v1.0.1] — Fast & Furious UI Fix

### Fixed
- Fixed the 21:9 layout of the vehicle confirmation screen displayed after selecting a car in Forza Horizon 2 Presents Fast & Furious.
- Repositioned manufacturer branding and vehicle statistics to better fit ultrawide displays.

### Unchanged
- No changes to the Forza Horizon 2 UI patch.
- Installer and uninstaller remained unchanged.

### Requirements
- Azimuth 0.9.10.

---

## [v1.0.0] — Initial Release

### Added
- Initial ultrawide UI patch for Forza Horizon 2 and Forza Horizon 2 Presents Fast & Furious.
- Repositioned HUD elements for 21:9 ultrawide displays.
- Adjusted UI layouts across menus and gameplay screens.
- Kept menus, dialogs, videos and loading screens centred in 16:9 where supported.
- Added black side bars during FH2 fast travel to hide the world loading outside the original 16:9 video area.
- Installer with file verification and automatic backups.
- Uninstaller to restore the original files.
- Optional compatibility adjustment for FH2 Extra Options 0.2.98.

### Tested Games
- Forza Horizon 2 — `1.0.0.64`
- Forza Horizon 2 Presents Fast & Furious — `1.0.0.6`

### Requirements
- Azimuth 0.9.10.
- Primary tested resolution: 3440×1440 (21:9).
