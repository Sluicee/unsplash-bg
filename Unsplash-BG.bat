@echo off
cd /d "%~dp0"
powershell.exe -ExecutionPolicy Bypass -File "Unsplash-BG.ps1" %*
pause
