@echo off
chcp 65001 >nul
cd /d "%~dp0"

set "PS=powershell.exe -NoProfile -ExecutionPolicy Bypass"
set "SCRIPTS=%~dp0scripts"

REM Check if config.json exists, if not, create from template
if not exist "config.json" (
    if exist "config.json.template" (
        echo Creating config.json from template...
        copy "config.json.template" "config.json" >nul
        echo Config file created successfully!
        echo.
    ) else (
        echo ERROR: config.json.template not found!
        echo Please ensure config.json.template exists in the project directory.
        pause
        exit /b 1
    )
)

:menu
cls
echo === Unsplash Background Changer - Setup ===
echo.
echo 1. Set API Key
echo 2. Set Category
echo 3. Set Resolution
echo 4. Set Wallpaper Style
echo 5. Test Connection
echo 6. Run Wallpaper Changer
echo 7. Auto-startup Settings
echo 0. Exit
echo.
set "choice="
set /p choice="Choose option (0-7): "

if "%choice%"=="1" goto setapikey
if "%choice%"=="2" goto setcategory
if "%choice%"=="3" goto setresolution
if "%choice%"=="4" goto setstyle
if "%choice%"=="5" goto testconnection
if "%choice%"=="6" goto runwallpaper
if "%choice%"=="7" goto autostartup
if "%choice%"=="0" goto exit
if "%choice%"=="" goto menu
echo Invalid choice. Try again.
pause
goto menu

:setapikey
cls
echo === Set API Key ===
echo.
echo To get API key:
echo 1. Go to https://unsplash.com/developers
echo 2. Create new application
echo 3. Copy Access Key
echo.
set "apikey="
set /p apikey="Enter API key: "
if not "%apikey%"=="" (
    %PS% -File "%SCRIPTS%\Set-Config.ps1" -Path unsplash.accessKey -Value "%apikey%"
) else (
    echo No API key entered.
)
pause
goto menu

:setcategory
cls
echo === Set Category ===
echo.
echo Available categories: nature, city, landscape, abstract, minimal, architecture, animals, food, people, technology
echo.
set "category="
set /p category="Enter category: "
if not "%category%"=="" (
    %PS% -File "%SCRIPTS%\Set-Config.ps1" -Path unsplash.defaultCategory -Value "%category%"
) else (
    echo No category entered.
)
pause
goto menu

:setresolution
cls
echo === Set Resolution ===
echo.
echo 1. 1920x1080 (Full HD)
echo 2. 2560x1440 (2K)
echo 3. 3840x2160 (4K)
echo 4. Auto-detect
echo 5. Custom
echo.
set "width="
set "height="
set "resolution="
set /p resolution="Choose resolution (1-5): "

if "%resolution%"=="1" (
    set "width=1920"
    set "height=1080"
    goto saveresolution
)
if "%resolution%"=="2" (
    set "width=2560"
    set "height=1440"
    goto saveresolution
)
if "%resolution%"=="3" (
    set "width=3840"
    set "height=2160"
    goto saveresolution
)
if "%resolution%"=="4" goto autoresolution
if "%resolution%"=="5" goto customresolution
echo Invalid choice.
pause
goto setresolution

:autoresolution
echo Auto-detecting resolution...
REM usebackq keeps the quoting inside the PowerShell command intact
for /f "usebackq tokens=1,2" %%a in (`%PS% -File "%SCRIPTS%\Get-Resolution.ps1"`) do (
    set "width=%%a"
    set "height=%%b"
)
goto saveresolution

:customresolution
set /p width="Enter width: "
set /p height="Enter height: "
goto saveresolution

:saveresolution
if "%width%"=="" goto noresolution
if "%height%"=="" goto noresolution
%PS% -File "%SCRIPTS%\Set-Config.ps1" -Path unsplash.defaultWidth -Value "%width%" -Type int
%PS% -File "%SCRIPTS%\Set-Config.ps1" -Path unsplash.defaultHeight -Value "%height%" -Type int
echo Resolution updated: %width%x%height%
set "width="
set "height="
pause
goto menu

:noresolution
echo No resolution set.
pause
goto menu

:setstyle
cls
echo === Set Wallpaper Style ===
echo.
echo 1. Fill - Fill screen (crop)
echo 2. Fit - Fit screen (no crop)
echo 3. Stretch - Stretch to screen
echo 4. Center - Center
echo 5. Tile - Tile
echo.
set "style="
set "stylechoice="
set /p stylechoice="Choose style (1-5): "

if "%stylechoice%"=="1" set "style=fill"
if "%stylechoice%"=="2" set "style=fit"
if "%stylechoice%"=="3" set "style=stretch"
if "%stylechoice%"=="4" set "style=center"
if "%stylechoice%"=="5" set "style=tile"

if not "%style%"=="" (
    %PS% -File "%SCRIPTS%\Set-Config.ps1" -Path wallpaper.style -Value "%style%"
) else (
    echo Invalid choice.
)
pause
goto menu

:testconnection
cls
echo === Test Connection ===
echo.
echo Testing connection to Unsplash API...
%PS% -File "%SCRIPTS%\Test-Connection.ps1"
pause
goto menu

:runwallpaper
cls
echo === Run Wallpaper Changer ===
echo.
echo Running Wallpaper Changer...
%PS% -File "%SCRIPTS%\Unsplash-BG.ps1"
pause
goto menu

:autostartup
cls
echo === Auto-startup Settings ===
echo.
echo 1. Enable auto-change wallpapers
echo 2. Set change interval
echo 3. Create/update Windows Task Scheduler task
echo 4. Remove Windows Task Scheduler task
echo 0. Back to main menu
echo.
echo Note: after changing the interval, re-create the task (option 3).
echo.
set "autochoice="
set /p autochoice="Choose option (0-4): "

if "%autochoice%"=="1" goto enableautochange
if "%autochoice%"=="2" goto setinterval
if "%autochoice%"=="3" goto createtask
if "%autochoice%"=="4" goto removetask
if "%autochoice%"=="0" goto menu
echo Invalid choice.
pause
goto autostartup

:enableautochange
cls
echo === Enable Auto-change ===
echo.
set "enable="
set /p enable="Enable auto-change wallpapers? (y/n): "
if /i "%enable%"=="y" (
    %PS% -File "%SCRIPTS%\Set-Config.ps1" -Path autoChange.enabled -Value true -Type bool
) else if /i "%enable%"=="n" (
    %PS% -File "%SCRIPTS%\Set-Config.ps1" -Path autoChange.enabled -Value false -Type bool
) else (
    echo Invalid choice.
)
pause
goto autostartup

:setinterval
cls
echo === Set Change Interval ===
echo.
echo 1. 15 minutes
echo 2. 30 minutes
echo 3. 1 hour
echo 4. 2 hours
echo 5. 6 hours
echo 6. 12 hours
echo 7. 24 hours
echo 8. Custom
echo.
set "minutes="
set "interval="
set /p interval="Choose interval (1-8): "

if "%interval%"=="1" set "minutes=15"
if "%interval%"=="2" set "minutes=30"
if "%interval%"=="3" set "minutes=60"
if "%interval%"=="4" set "minutes=120"
if "%interval%"=="5" set "minutes=360"
if "%interval%"=="6" set "minutes=720"
if "%interval%"=="7" set "minutes=1440"
if "%interval%"=="8" goto custominterval
goto saveinterval

:custominterval
set /p minutes="Enter interval in minutes: "
goto saveinterval

:saveinterval
if not "%minutes%"=="" (
    %PS% -File "%SCRIPTS%\Set-Config.ps1" -Path autoChange.intervalMinutes -Value "%minutes%" -Type int
) else (
    echo Invalid choice.
)
set "minutes="
pause
goto autostartup

:createtask
cls
echo === Create Windows Task Scheduler Task ===
echo.
echo Creating task for the current user (no admin rights needed)...
%PS% -File "%SCRIPTS%\Create-Task.ps1"
pause
goto autostartup

:removetask
cls
echo === Remove Windows Task Scheduler Task ===
echo.
echo Removing Windows Task Scheduler task...
%PS% -File "%SCRIPTS%\Remove-Task.ps1"
pause
goto autostartup

:exit
echo Goodbye!
exit /b 0
