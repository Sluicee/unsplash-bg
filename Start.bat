@echo off
chcp 65001 >nul
cd /d "%~dp0"
echo === Unsplash Background Changer ===
echo.
echo 1. Сменить обои
echo 2. Настройка
echo 3. История обоев
echo 4. Восстановить обои
echo 0. Выход
echo.
set /p choice="Выберите действие (0-4): "

if "%choice%"=="1" (
    echo Запуск смены обоев...
    powershell.exe -ExecutionPolicy Bypass -File "Unsplash-BG.ps1"
    pause
) else if "%choice%"=="2" (
    echo Запуск конфигуратора...
    powershell.exe -ExecutionPolicy Bypass -File "Config-Manager.ps1"
) else if "%choice%"=="3" (
    echo Просмотр истории...
    powershell.exe -ExecutionPolicy Bypass -File "Unsplash-BG.ps1" -ShowHistory
    pause
) else if "%choice%"=="4" (
    set /p historyId="Введите ID изображения: "
    echo Восстановление обоев...
    powershell.exe -ExecutionPolicy Bypass -File "Unsplash-BG.ps1" -RestoreFromHistory %historyId%
    pause
) else if "%choice%"=="0" (
    echo До свидания!
    exit
) else (
    echo Неверный выбор
    pause
    goto :eof
)
