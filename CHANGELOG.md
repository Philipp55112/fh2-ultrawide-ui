# Changelog

All notable changes to the Forza 21:9 Ultrawide UI Patch are documented here.

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

### Known Issues
- The current Forza Motorsport 5 UI fix requires **3440×1440**.
- Performance drops in the garage and pre-race screens remain unresolved. The cause may be the patch or Azimuth.
- Other ultrawide resolutions have not all been tested.

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
