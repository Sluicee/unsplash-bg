@echo off
chcp 65001 >nul
cd /d "%~dp0"
echo === Unsplash Background Changer - Configuration ===
echo.
echo 1. API Settings (Access Key)
echo 2. Display Settings (Resolution, Category)  
echo 3. Wallpaper Style (Fill/Fit/Stretch/Center/Tile)
echo 4. Auto-change Settings (Enable/Interval)
echo 5. Task Scheduler Setup
echo 6. History Settings (Max cache, Keep images)
echo 7. View/Restore History
echo 8. Test Connection
echo 9. Save and Exit
echo 0. Exit without saving
echo.
set /p choice="Выберите опцию (0-9): "

if "%choice%"=="1" (
    echo Настройка API ключа...
    echo Для получения API ключа:
    echo 1. Перейдите на https://unsplash.com/developers
    echo 2. Создайте новое приложение
    echo 3. Скопируйте Access Key
    echo.
    set /p apikey="Введите API ключ: "
    if not "%apikey%"=="" (
        powershell.exe -ExecutionPolicy Bypass -Command "& {$config = Get-Content 'config.json' -Raw | ConvertFrom-Json -AsHashtable; $config.unsplash.accessKey = '%apikey%'; $config | ConvertTo-Json -Depth 3 | Set-Content 'config.json'}"
        echo API ключ обновлен!
    )
    pause
) else if "%choice%"=="2" (
    echo Настройка дисплея...
    echo Доступные категории:
    echo 1. nature, 2. city, 3. landscape, 4. abstract, 5. minimal
    echo 6. architecture, 7. animals, 8. food, 9. people, 10. technology
    echo.
    set /p category="Введите категорию (или номер 1-10): "
    if "%category%"=="1" set category=nature
    if "%category%"=="2" set category=city
    if "%category%"=="3" set category=landscape
    if "%category%"=="4" set category=abstract
    if "%category%"=="5" set category=minimal
    if "%category%"=="6" set category=architecture
    if "%category%"=="7" set category=animals
    if "%category%"=="8" set category=food
    if "%category%"=="9" set category=people
    if "%category%"=="10" set category=technology
    
    echo.
    echo Настройка разрешения:
    echo 1. 1920x1080 (Full HD)
    echo 2. 2560x1440 (2K)  
    echo 3. 3840x2160 (4K)
    echo 4. Определить автоматически
    echo 5. Ввести вручную
    echo.
    set /p resolution="Выберите разрешение (1-5): "
    
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
        echo Определение разрешения...
        for /f "tokens=2 delims=:" %%a in ('wmic path Win32_VideoController get CurrentHorizontalResolution /value ^| find "="') do set width=%%a
        for /f "tokens=2 delims=:" %%a in ('wmic path Win32_VideoController get CurrentVerticalResolution /value ^| find "="') do set height=%%a
        echo Автоматически определено: %width%x%height%
    ) else if "%resolution%"=="5" (
        set /p width="Введите ширину: "
        set /p height="Введите высоту: "
    )
    
    if not "%category%"=="" (
        powershell.exe -ExecutionPolicy Bypass -Command "& {$config = Get-Content 'config.json' -Raw | ConvertFrom-Json -AsHashtable; $config.unsplash.defaultCategory = '%category%'; $config | ConvertTo-Json -Depth 3 | Set-Content 'config.json'}"
    )
    if not "%width%"=="" (
        powershell.exe -ExecutionPolicy Bypass -Command "& {$config = Get-Content 'config.json' -Raw | ConvertFrom-Json -AsHashtable; $config.unsplash.defaultWidth = %width%; $config.unsplash.defaultHeight = %height%; $config | ConvertTo-Json -Depth 3 | Set-Content 'config.json'}"
    )
    echo Настройки обновлены!
    pause
) else if "%choice%"=="3" (
    echo Настройка стиля обоев...
    echo 1. Fill - Заполнить экран (обрезание)
    echo 2. Fit - Поместить в экран (без обрезания)
    echo 3. Stretch - Растянуть на весь экран
    echo 4. Center - По центру
    echo 5. Tile - Мозаика
    echo.
    set /p style="Выберите стиль (1-5): "
    
    if "%style%"=="1" set style=fill
    if "%style%"=="2" set style=fit
    if "%style%"=="3" set style=stretch
    if "%style%"=="4" set style=center
    if "%style%"=="5" set style=tile
    
    if not "%style%"=="" (
        powershell.exe -ExecutionPolicy Bypass -Command "& {$config = Get-Content 'config.json' -Raw | ConvertFrom-Json -AsHashtable; $config.wallpaper.style = '%style%'; $config | ConvertTo-Json -Depth 3 | Set-Content 'config.json'}"
        echo Стиль обоев установлен: %style%
    )
    pause
) else if "%choice%"=="4" (
    echo Настройка автозамены...
    set /p auto="Включить автозамену обоев? (y/n): "
    if "%auto%"=="y" (
        echo Настройка интервала:
        echo 1. 15 минут, 2. 30 минут, 3. 1 час, 4. 2 часа
        echo 5. 6 часов, 6. 12 часов, 7. 24 часа, 8. Ввести вручную
        echo.
        set /p interval="Выберите интервал (1-8): "
        
        if "%interval%"=="1" set minutes=15
        if "%interval%"=="2" set minutes=30
        if "%interval%"=="3" set minutes=60
        if "%interval%"=="4" set minutes=120
        if "%interval%"=="5" set minutes=360
        if "%interval%"=="6" set minutes=720
        if "%interval%"=="7" set minutes=1440
        if "%interval%"=="8" (
            set /p minutes="Введите интервал в минутах: "
        )
        
        set /p startup="Запускать при старте системы? (y/n): "
        
        powershell.exe -ExecutionPolicy Bypass -Command "& {$config = Get-Content 'config.json' -Raw | ConvertFrom-Json -AsHashtable; $config.autoChange.enabled = $true; $config.autoChange.intervalMinutes = %minutes%; $config.autoChange.runAtStartup = $%startup% -eq 'y'; $config | ConvertTo-Json -Depth 3 | Set-Content 'config.json'}"
        echo Автозамена настроена!
    ) else (
        powershell.exe -ExecutionPolicy Bypass -Command "& {$config = Get-Content 'config.json' -Raw | ConvertFrom-Json -AsHashtable; $config.autoChange.enabled = $false; $config | ConvertTo-Json -Depth 3 | Set-Content 'config.json'}"
        echo Автозамена отключена
    )
    pause
) else if "%choice%"=="5" (
    echo Настройка планировщика задач...
    echo Создание задачи Windows Task Scheduler...
    powershell.exe -ExecutionPolicy Bypass -Command "& {$config = Get-Content 'config.json' -Raw | ConvertFrom-Json -AsHashtable; if ($config.autoChange.enabled) { $taskName = $config.taskScheduler.taskName; $action = New-ScheduledTaskAction -Execute 'PowerShell.exe' -Argument '-WindowStyle Hidden -ExecutionPolicy Bypass -File \"$PSScriptRoot\Unsplash-BG.ps1\" -Schedule'; $trigger = New-ScheduledTaskTrigger -RepetitionInterval (New-TimeSpan -Minutes $config.autoChange.intervalMinutes) -RepetitionDuration (New-TimeSpan -Days 365) -At (Get-Date); if ($config.autoChange.runAtStartup) { $startupTrigger = New-ScheduledTaskTrigger -AtStartup; $trigger = @($trigger, $startupTrigger) }; $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable; $principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType InteractiveToken; Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Description 'Unsplash Background Changer - автоматическая смена обоев'; Write-Host 'Задача планировщика создана!' -ForegroundColor Green } else { Write-Host 'Сначала включите автозамену в настройках!' -ForegroundColor Red }}"
    pause
) else if "%choice%"=="6" (
    echo Настройка истории...
    set /p maxEntries="Введите максимальное количество записей в истории (текущее: 50): "
    set /p keepFiles="Сохранять файлы изображений? (y/n): "
    
    if not "%maxEntries%"=="" (
        powershell.exe -ExecutionPolicy Bypass -Command "& {$config = Get-Content 'config.json' -Raw | ConvertFrom-Json -AsHashtable; $config.history.maxEntries = %maxEntries%; $config | ConvertTo-Json -Depth 3 | Set-Content 'config.json'}"
    )
    if not "%keepFiles%"=="" (
        powershell.exe -ExecutionPolicy Bypass -Command "& {$config = Get-Content 'config.json' -Raw | ConvertFrom-Json -AsHashtable; $config.history.keepFiles = $%keepFiles% -eq 'y'; $config | ConvertTo-Json -Depth 3 | Set-Content 'config.json'}"
    )
    echo Настройки истории обновлены!
    pause
) else if "%choice%"=="7" (
    echo Просмотр истории обоев...
    powershell.exe -ExecutionPolicy Bypass -File "Unsplash-BG.ps1" -ShowHistory
    pause
) else if "%choice%"=="8" (
    echo Тестирование соединения с Unsplash API...
    powershell.exe -ExecutionPolicy Bypass -Command "& {$config = Get-Content 'config.json' -Raw | ConvertFrom-Json -AsHashtable; if ([string]::IsNullOrEmpty($config.unsplash.accessKey)) { Write-Host 'API ключ не настроен!' -ForegroundColor Red } else { try { $apiUrl = '$($config.unsplash.apiUrl)/photos/random'; $headers = @{'Authorization' = 'Client-ID $($config.unsplash.accessKey)'; 'Accept-Version' = 'v1'}; $response = Invoke-RestMethod -Uri $apiUrl -Headers $headers -Method Get; Write-Host 'Соединение успешно!' -ForegroundColor Green; Write-Host 'Получено изображение: $($response.description ?? $response.alt_description ?? 'Без описания')' -ForegroundColor White; Write-Host 'Автор: $($response.user.name)' -ForegroundColor Gray } catch { Write-Host 'ОШИБКА: $($_.Exception.Message)' -ForegroundColor Red }}}"
    pause
) else if "%choice%"=="9" (
    echo Конфигурация сохранена. До свидания!
    exit
) else if "%choice%"=="0" (
    echo Выход без сохранения. До свидания!
    exit
) else (
    echo Неверный выбор. Попробуйте снова.
    pause
    goto :eof
)
