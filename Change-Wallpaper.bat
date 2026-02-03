@echo off
cd /d "%~dp0"

REM Check if config.json exists, if not, create from template
if not exist "config.json" (
    if exist "config.json.template" (
        echo Creating config.json from template...
        copy "config.json.template" "config.json" >nul
        echo Config file created! Please run Setup.bat to configure.
        pause
        exit /b 1
    ) else (
        echo ERROR: config.json.template not found!
        echo Please ensure config.json.template exists in the project directory.
        pause
        exit /b 1
    )
)

echo Changing wallpaper...
powershell.exe -ExecutionPolicy Bypass -File "scripts\Unsplash-BG.ps1"
