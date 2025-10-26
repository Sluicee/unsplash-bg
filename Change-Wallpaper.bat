@echo off
cd /d "%~dp0"
echo Changing wallpaper...
powershell.exe -ExecutionPolicy Bypass -File "Unsplash-BG.ps1"
