@echo off
chcp 65001 >nul
cd /d "%~dp0"

REM Check if config.json exists
if not exist "config.json" (
    echo Creating config.json from template...
    copy "config.json.template" "config.json" >nul
    echo Config file created!
    echo.
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
set /p apikey="Enter API key: "
if not "%apikey%"=="" (
    powershell.exe -ExecutionPolicy Bypass -Command "$config = Get-Content 'config.json' -Raw | ConvertFrom-Json; $config.unsplash.accessKey = '%apikey%'; $config | ConvertTo-Json -Depth 3 | Set-Content 'config.json'"
    echo API key updated!
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
set /p category="Enter category: "
if not "%category%"=="" (
    powershell.exe -ExecutionPolicy Bypass -Command "$config = Get-Content 'config.json' -Raw | ConvertFrom-Json; $config.unsplash.defaultCategory = '%category%'; $config | ConvertTo-Json -Depth 3 | Set-Content 'config.json'"
    echo Category updated!
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
set /p resolution="Choose resolution (1-5): "

if "%resolution%"=="1" (
    set width=1920
    set height=1080
    goto saveresolution
)
if "%resolution%"=="2" (
    set width=2560
    set height=1440
    goto saveresolution
)
if "%resolution%"=="3" (
    set width=3840
    set height=2160
    goto saveresolution
)
if "%resolution%"=="4" (
    echo Auto-detecting resolution...
    for /f "tokens=2 delims=:" %%a in ('wmic path Win32_VideoController get CurrentHorizontalResolution /value ^| find "="') do set width=%%a
    for /f "tokens=2 delims=:" %%a in ('wmic path Win32_VideoController get CurrentVerticalResolution /value ^| find "="') do set height=%%a
    echo Auto-detected: %width%x%height%
    goto saveresolution
)
if "%resolution%"=="5" (
    set /p width="Enter width: "
    set /p height="Enter height: "
    goto saveresolution
)
echo Invalid choice.
pause
goto setresolution

:saveresolution
if not "%width%"=="" (
    powershell.exe -ExecutionPolicy Bypass -Command "$config = Get-Content 'config.json' -Raw | ConvertFrom-Json; $config.unsplash.defaultWidth = %width%; $config.unsplash.defaultHeight = %height%; $config | ConvertTo-Json -Depth 3 | Set-Content 'config.json'"
    echo Resolution updated: %width%x%height%
) else (
    echo No resolution set.
)
set width=
set height=
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
set /p style="Choose style (1-5): "

if "%style%"=="1" set style=fill
if "%style%"=="2" set style=fit
if "%style%"=="3" set style=stretch
if "%style%"=="4" set style=center
if "%style%"=="5" set style=tile

if not "%style%"=="" (
    powershell.exe -ExecutionPolicy Bypass -Command "$config = Get-Content 'config.json' -Raw | ConvertFrom-Json; $config.wallpaper.style = '%style%'; $config | ConvertTo-Json -Depth 3 | Set-Content 'config.json'"
    echo Wallpaper style set: %style%
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
powershell.exe -ExecutionPolicy Bypass -Command "try { $config = Get-Content 'config.json' -Raw | ConvertFrom-Json; if ([string]::IsNullOrEmpty($config.unsplash.accessKey)) { Write-Host 'API key not configured!' -ForegroundColor Red } else { $apiUrl = '$($config.unsplash.apiUrl)/photos/random'; $headers = @{'Authorization' = 'Client-ID $($config.unsplash.accessKey)'; 'Accept-Version' = 'v1'}; $response = Invoke-RestMethod -Uri $apiUrl -Headers $headers -Method Get; Write-Host 'Connection successful!' -ForegroundColor Green; Write-Host 'Image: $($response.description)' -ForegroundColor White; Write-Host 'Author: $($response.user.name)' -ForegroundColor Gray } } catch { Write-Host 'ERROR: $($_.Exception.Message)' -ForegroundColor Red }"
pause
goto menu

:runwallpaper
cls
echo === Run Wallpaper Changer ===
echo.
echo Running Wallpaper Changer...
powershell.exe -ExecutionPolicy Bypass -File "scripts\Unsplash-BG.ps1"
pause
goto menu

:autostartup
cls
echo === Auto-startup Settings ===
echo.
echo 1. Enable auto-change wallpapers
echo 2. Set change interval
echo 3. Enable run at startup
echo 4. Create Windows Task Scheduler task
echo 5. Remove Windows Task Scheduler task
echo 0. Back to main menu
echo.
set /p autochoice="Choose option (0-5): "

if "%autochoice%"=="1" goto enableautochange
if "%autochoice%"=="2" goto setinterval
if "%autochoice%"=="3" goto enablestartup
if "%autochoice%"=="4" goto createtask
if "%autochoice%"=="5" goto removetask
if "%autochoice%"=="0" goto menu
echo Invalid choice.
pause
goto autostartup

:enableautochange
cls
echo === Enable Auto-change ===
echo.
set /p enable="Enable auto-change wallpapers? (y/n): "
if /i "%enable%"=="y" (
    powershell.exe -ExecutionPolicy Bypass -Command "$config = Get-Content 'config.json' -Raw | ConvertFrom-Json; $config.autoChange.enabled = $true; $config | ConvertTo-Json -Depth 3 | Set-Content 'config.json'"
    echo Auto-change enabled!
) else if /i "%enable%"=="n" (
    powershell.exe -ExecutionPolicy Bypass -Command "$config = Get-Content 'config.json' -Raw | ConvertFrom-Json; $config.autoChange.enabled = $false; $config | ConvertTo-Json -Depth 3 | Set-Content 'config.json'"
    echo Auto-change disabled!
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
set /p interval="Choose interval (1-8): "

if "%interval%"=="1" set minutes=15
if "%interval%"=="2" set minutes=30
if "%interval%"=="3" set minutes=60
if "%interval%"=="4" set minutes=120
if "%interval%"=="5" set minutes=360
if "%interval%"=="6" set minutes=720
if "%interval%"=="7" set minutes=1440
if "%interval%"=="8" (
    set /p minutes="Enter interval in minutes: "
)

if not "%minutes%"=="" (
    powershell.exe -ExecutionPolicy Bypass -Command "$config = Get-Content 'config.json' -Raw | ConvertFrom-Json; $config.autoChange.intervalMinutes = %minutes%; $config | ConvertTo-Json -Depth 3 | Set-Content 'config.json'"
    echo Interval set to %minutes% minutes!
) else (
    echo Invalid choice.
)
set minutes=
pause
goto autostartup

:enablestartup
cls
echo === Enable Run at Startup ===
echo.
set /p startup="Run at system startup? (y/n): "
if /i "%startup%"=="y" (
    powershell.exe -ExecutionPolicy Bypass -Command "$config = Get-Content 'config.json' -Raw | ConvertFrom-Json; $config.autoChange.runAtStartup = $true; $config | ConvertTo-Json -Depth 3 | Set-Content 'config.json'"
    echo Run at startup enabled!
) else if /i "%startup%"=="n" (
    powershell.exe -ExecutionPolicy Bypass -Command "$config = Get-Content 'config.json' -Raw | ConvertFrom-Json; $config.autoChange.runAtStartup = $false; $config | ConvertTo-Json -Depth 3 | Set-Content 'config.json'"
    echo Run at startup disabled!
) else (
    echo Invalid choice.
)
pause
goto autostartup

:createtask
cls
echo === Create Windows Task Scheduler Task ===
echo.
echo Creating Windows Task Scheduler task...
powershell.exe -ExecutionPolicy Bypass -Command "Start-Process powershell -ArgumentList '-ExecutionPolicy Bypass -File scripts\Create-Task.ps1' -Verb RunAs"
pause
goto autostartup

:removetask
cls
echo === Remove Windows Task Scheduler Task ===
echo.
echo Removing Windows Task Scheduler task...
powershell.exe -ExecutionPolicy Bypass -Command "Start-Process powershell -ArgumentList '-ExecutionPolicy Bypass -File scripts\Remove-Task.ps1' -Verb RunAs"
pause
goto autostartup

:exit
echo Goodbye!
exit
