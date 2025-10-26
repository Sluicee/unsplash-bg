@echo off
chcp 65001 >nul
cd /d "%~dp0"
echo === Unsplash Background Changer - Simple Configuration ===
echo.
echo 1. Set API Key
echo 2. Set Category  
echo 3. Set Resolution
echo 4. Set Wallpaper Style
echo 5. Enable Auto-change
echo 6. Test Connection
echo 7. Save and Exit
echo 0. Exit without saving
echo.
set /p choice="Choose option (0-7): "

if "%choice%"=="1" (
    echo.
    echo Setting API Key...
    echo To get API key:
    echo 1. Go to https://unsplash.com/developers
    echo 2. Create new application
    echo 3. Copy Access Key
    echo.
    set /p apikey="Enter API key: "
    if not "%apikey%"=="" (
        powershell.exe -ExecutionPolicy Bypass -Command "$config = Get-Content 'config.json' -Raw | ConvertFrom-Json; $config.unsplash.accessKey = '%apikey%'; $config | ConvertTo-Json -Depth 3 | Set-Content 'config.json'"
        echo API key updated!
    )
    pause
) else if "%choice%"=="2" (
    echo.
    echo Setting Category...
    echo Available categories: nature, city, landscape, abstract, minimal, architecture, animals, food, people, technology
    echo.
    set /p category="Enter category: "
    if not "%category%"=="" (
        powershell.exe -ExecutionPolicy Bypass -Command "$config = Get-Content 'config.json' -Raw | ConvertFrom-Json; $config.unsplash.defaultCategory = '%category%'; $config | ConvertTo-Json -Depth 3 | Set-Content 'config.json'"
        echo Category updated!
    )
    pause
) else if "%choice%"=="3" (
    echo.
    echo Setting Resolution...
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
    ) else if "%resolution%"=="2" (
        set width=2560
        set height=1440
    ) else if "%resolution%"=="3" (
        set width=3840
        set height=2160
    ) else if "%resolution%"=="4" (
        echo Auto-detecting resolution...
        for /f "tokens=2 delims=:" %%a in ('wmic path Win32_VideoController get CurrentHorizontalResolution /value ^| find "="') do set width=%%a
        for /f "tokens=2 delims=:" %%a in ('wmic path Win32_VideoController get CurrentVerticalResolution /value ^| find "="') do set height=%%a
        echo Auto-detected: %width%x%height%
    ) else if "%resolution%"=="5" (
        set /p width="Enter width: "
        set /p height="Enter height: "
    )
    
    if not "%width%"=="" (
        powershell.exe -ExecutionPolicy Bypass -Command "$config = Get-Content 'config.json' -Raw | ConvertFrom-Json; $config.unsplash.defaultWidth = %width%; $config.unsplash.defaultHeight = %height%; $config | ConvertTo-Json -Depth 3 | Set-Content 'config.json'"
        echo Resolution updated: %width%x%height%
    )
    pause
) else if "%choice%"=="4" (
    echo.
    echo Setting Wallpaper Style...
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
    )
    pause
) else if "%choice%"=="5" (
    echo.
    echo Auto-change Settings...
    set /p auto="Enable auto-change? (y/n): "
    if "%auto%"=="y" (
        echo.
        echo Set interval:
        echo 1. 15 minutes, 2. 30 minutes, 3. 1 hour, 4. 2 hours
        echo 5. 6 hours, 6. 12 hours, 7. 24 hours, 8. Custom
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
        
        set /p startup="Run at system startup? (y/n): "
        
        powershell.exe -ExecutionPolicy Bypass -Command "$config = Get-Content 'config.json' -Raw | ConvertFrom-Json; $config.autoChange.enabled = $true; $config.autoChange.intervalMinutes = %minutes%; if ('%startup%' -eq 'y') { $config.autoChange.runAtStartup = $true } else { $config.autoChange.runAtStartup = $false }; $config | ConvertTo-Json -Depth 3 | Set-Content 'config.json'"
        echo Auto-change enabled!
    ) else (
        powershell.exe -ExecutionPolicy Bypass -Command "$config = Get-Content 'config.json' -Raw | ConvertFrom-Json; $config.autoChange.enabled = $false; $config | ConvertTo-Json -Depth 3 | Set-Content 'config.json'"
        echo Auto-change disabled
    )
    pause
) else if "%choice%"=="6" (
    echo.
    echo Testing connection to Unsplash API...
    powershell.exe -ExecutionPolicy Bypass -Command "try { $config = Get-Content 'config.json' -Raw | ConvertFrom-Json; if ([string]::IsNullOrEmpty($config.unsplash.accessKey)) { Write-Host 'API key not configured!' -ForegroundColor Red } else { $apiUrl = '$($config.unsplash.apiUrl)/photos/random'; $headers = @{'Authorization' = 'Client-ID $($config.unsplash.accessKey)'; 'Accept-Version' = 'v1'}; $response = Invoke-RestMethod -Uri $apiUrl -Headers $headers -Method Get; Write-Host 'Connection successful!' -ForegroundColor Green; Write-Host 'Image: $($response.description)' -ForegroundColor White; Write-Host 'Author: $($response.user.name)' -ForegroundColor Gray } } catch { Write-Host 'ERROR: $($_.Exception.Message)' -ForegroundColor Red }"
    pause
) else if "%choice%"=="7" (
    echo Configuration saved. Goodbye!
    exit
) else if "%choice%"=="0" (
    echo Exit without saving. Goodbye!
    exit
) else (
    echo Invalid choice. Try again.
    pause
    goto :eof
)
