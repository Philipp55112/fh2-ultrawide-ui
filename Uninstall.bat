@echo off
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0FH2_Ultrawide.ps1" -Uninstall %*
echo.
pause
