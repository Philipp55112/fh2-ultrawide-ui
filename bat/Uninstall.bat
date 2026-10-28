@echo off
rem Forza 21:9 Ultrawide Patch - console uninstall (asks for administrator rights: Azimuth usually lives under Program Files)
net session >nul 2>&1
if %errorlevel% neq 0 ( powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs" & exit /b )
powershell -NoProfile -STA -ExecutionPolicy Bypass -File "%~dp0Forza21x9.ps1" -NoGui -Uninstall
echo.
pause
