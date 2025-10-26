@echo off
cd /d "%~dp0"
powershell.exe -ExecutionPolicy Bypass -File "Run-Scripts.ps1"
pause
