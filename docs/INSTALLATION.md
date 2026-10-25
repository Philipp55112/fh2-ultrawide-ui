# Installation Guide

## FH2 Ultrawide UI — Installer v1.0

The installer applies the ultrawide UI modification to supported Forza Horizon 2 installations using Azimuth.

It supports both:

- Forza Horizon 2 — Xbox One version 1.0.0.64
- Forza Horizon 2 Presents Fast & Furious — version 1.0.0.6

## Requirements

- Windows 10 or Windows 11
- Azimuth 0.9.10
- An original, unmodified `azimuth.exe`
- An original `Mount\media\UI.zip` and matching `zipmanifest.xml` for the target game
- Optional: FH2 Extra Options 0.2.98

Each game must use its own Azimuth directory. Run the installer separately for each game.

## Installation

1. Extract the release package to a folder.
2. Run `Install.bat`.
3. If the Azimuth directory cannot be detected automatically, provide its path when prompted.
4. Review the detected game and proposed display resolution.
5. Follow the prompts to configure the installation and optional Extra Options compatibility.
6. Review the final summary and confirm the installation.
7. Start the game using `azimuth.exe` as usual.

The installer checks supported files before making changes and creates backups of the original files.

## Resolution support

The installer can calculate UI layout values from the selected display resolution.

**3440×1440 (21:9) is the tested configuration.** Other resolutions may work, but are not fully tested. The installer rejects 16:9 and 16:10 configurations.

If you change resolutions after installation, uninstall the modification and run the installer again.

## Uninstallation

1. Run `Uninstall.bat`.
2. Provide the Azimuth directory if prompted.
3. Allow the installer to restore the original files from the backup.

The uninstaller verifies that the original `azimuth.exe` has been restored.

## Important notes

- Always use the `UI.zip` and `zipmanifest.xml` supplied by the same game installation.
- Do not modify the files while installation is in progress.
- The installer refuses to install over an existing installation. Uninstall first.
- To modify both games, run the installer separately for each Azimuth directory.
- Keep backups until you have confirmed that the game works correctly.

