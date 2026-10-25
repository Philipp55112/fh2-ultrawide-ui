# FH2 Ultrawide UI

**A true 21:9 ultrawide UI modification for Forza Horizon 2 on PC using Azimuth.**

This project aims to make *Forza Horizon 2* work properly on ultrawide displays while preserving the original 16:9 presentation of menus, videos and loading screens.

## Features

- **Ultrawide HUD:** Repositioned HUD elements for 3440×1440 displays.
- **Original menu layout:** Pause menus, vehicle selection and options retain their 16:9 layout.
- **Correct video presentation:** Intro videos and loading screens remain in 16:9 instead of being stretched.
- **World UI fixes:** Adjusted event markers, checkpoints, nameplates and race overlays.
- **Photo mode adjustments:** Repositioned UI panels for ultrawide screens.
- **Extra Options compatibility:** Tested with FH2 Extra Options 0.2.98.
- **Fast & Furious compatibility:** Tested successfully with Forza Horizon 2: Fast & Furious.

## Tested configurations

### Forza Horizon 2

| Component | Version / Setting |
|---|---|
| Game | Forza Horizon 2 — Xbox One version 1.0.0.64 |
| Game package | `Anthem_1.0.0.64_x64__8wekyb3d8bbwe` |
| Wrapper | Azimuth 0.9.10 |
| Resolution | 3440×1440 |
| Aspect ratio | 21:9 |
| Modified XAML files | 49 |

### Forza Horizon 2: Fast & Furious

| Component | Version / Setting |
|---|---|
| Game | Forza Horizon 2: Fast & Furious |
| Game package | `Spire_1.0.0.6_x64__8wekyb3d8bbwe` |
| Wrapper | Azimuth 0.9.10 |
| Resolution | 3440×1440 |
| Aspect ratio | 21:9 |
| Modified XAML files | 50 |

Both game versions have been tested with the ultrawide UI modifications.



## Technical overview

The modification extends the UI canvas and adjusts clipping-related constants in Azimuth. Selected UI elements are repositioned to use the wider screen, while menus and video content retain their original 16:9 presentation.

The original game executable remains unmodified.

## Installation

Installation instructions and release files will be published here.

The modified UI archive must always be paired with its matching `zipmanifest.xml`.

## Compatibility

The primary target is 3440×1440 at 21:9 using Azimuth 0.9.10. Other resolutions and configurations may require additional adjustments.

## Disclaimer

This is an unofficial community project. It is not affiliated with or endorsed by Microsoft, Xbox, Playground Games or the Azimuth project.

All third-party components remain subject to their respective licenses.

## Development Tools & AI Assistance

Claude (Anthropic) was used as an AI-assisted development and research tool throughout this project. It helped with technical analysis, exploring UI layout changes, reviewing XAML modifications, troubleshooting and documenting the implementation.

The modifications were tested in-game, with adjustments made based on the observed results.

The project involved reverse engineering Azimuth's UI-related behavior, modifying UI layout definitions and validating the results in both Forza Horizon 2 and Forza Horizon 2: Fast & Furious.



