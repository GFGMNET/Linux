@echo off
rem Double-click to check all package names in the profiles (no Python needed).
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0check-profiles.ps1" %*
pause
