@echo off
cd /d "%~dp0"
powershell.exe -ExecutionPolicy Bypass -File "Config-Manager.ps1"
pause
