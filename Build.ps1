#Requires -Version 5.1

<#
.SYNOPSIS
	Build script for Unsplash Background Changer
	
.DESCRIPTION
	Компилирует PowerShell скрипты в исполняемые файлы .exe
	
.EXAMPLE
	.\Build.ps1
#>

# Проверяем наличие ps2exe
if (!(Get-Module -ListAvailable -Name ps2exe)) {
	Write-Host "Установка модуля ps2exe..." -ForegroundColor Yellow
	try {
		Install-Module ps2exe -Force -Scope CurrentUser
		Write-Host "Модуль ps2exe установлен!" -ForegroundColor Green
	}
	catch {
		Write-Host "ОШИБКА: Не удалось установить ps2exe. Запустите PowerShell от имени администратора." -ForegroundColor Red
		exit 1
	}
}

# Импортируем модуль
Import-Module ps2exe -Force

# Создаем папку bin если не существует
$binPath = "$PSScriptRoot\bin"
if (!(Test-Path $binPath)) {
	New-Item -ItemType Directory -Path $binPath -Force | Out-Null
	Write-Host "Создана папка bin" -ForegroundColor Green
}

Write-Host "=== Сборка Unsplash Background Changer ===" -ForegroundColor Cyan
Write-Host ""

# Компилируем основной скрипт
Write-Host "Компиляция Unsplash-BG.ps1..." -ForegroundColor Yellow
try {
	ps2exe -inputFile "$PSScriptRoot\Unsplash-BG.ps1" -outputFile "$binPath\Unsplash-BG.exe" -noConsole -requireAdmin -title "Unsplash Background Changer" -description "Автоматическая смена обоев с Unsplash"
	Write-Host "✓ Unsplash-BG.exe создан" -ForegroundColor Green
}
catch {
	Write-Host "✗ ОШИБКА при компиляции Unsplash-BG.ps1: $($_.Exception.Message)" -ForegroundColor Red
}

# Компилируем конфигуратор
Write-Host "Компиляция Config-Manager.ps1..." -ForegroundColor Yellow
try {
	ps2exe -inputFile "$PSScriptRoot\Config-Manager.ps1" -outputFile "$binPath\Config.exe" -requireAdmin -title "Unsplash BG Config" -description "Конфигуратор для Unsplash Background Changer"
	Write-Host "✓ Config.exe создан" -ForegroundColor Green
}
catch {
	Write-Host "✗ ОШИБКА при компиляции Config-Manager.ps1: $($_.Exception.Message)" -ForegroundColor Red
}

# Копируем конфигурацию
Write-Host "Копирование конфигурации..." -ForegroundColor Yellow
try {
	Copy-Item "$PSScriptRoot\config.json" "$binPath\config.json" -Force
	Write-Host "✓ config.json скопирован" -ForegroundColor Green
}
catch {
	Write-Host "✗ ОШИБКА при копировании config.json: $($_.Exception.Message)" -ForegroundColor Red
}

# Копируем README
Write-Host "Копирование документации..." -ForegroundColor Yellow
try {
	Copy-Item "$PSScriptRoot\README.md" "$binPath\README.md" -Force
	Write-Host "✓ README.md скопирован" -ForegroundColor Green
}
catch {
	Write-Host "✗ ОШИБКА при копировании README.md: $($_.Exception.Message)" -ForegroundColor Red
}

# Копируем INSTALL.md
Write-Host "Копирование INSTALL.md..." -ForegroundColor Yellow
try {
	Copy-Item "$PSScriptRoot\INSTALL.md" "$binPath\INSTALL.md" -Force
	Write-Host "✓ INSTALL.md скопирован" -ForegroundColor Green
}
catch {
	Write-Host "✗ ОШИБКА при копировании INSTALL.md: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "=== Сборка завершена ===" -ForegroundColor Cyan
Write-Host "Исполняемые файлы находятся в папке: $binPath" -ForegroundColor White
Write-Host ""
Write-Host "Для настройки запустите: $binPath\Config.exe" -ForegroundColor Yellow
Write-Host "Для смены обоев запустите: $binPath\Unsplash-BG.exe" -ForegroundColor Yellow
