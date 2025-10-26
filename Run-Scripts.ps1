#Requires -Version 5.1

<#
.SYNOPSIS
	Launcher script for Unsplash Background Changer
	
.DESCRIPTION
	Запускает PowerShell скрипты напрямую, обходя проблемы с антивирусом
	
.EXAMPLE
	.\Run-Scripts.ps1
#>

param(
	[string]$Action = "menu"
)

function Show-Menu {
	Clear-Host
	Write-Host "=== Unsplash Background Changer ===" -ForegroundColor Cyan
	Write-Host ""
	Write-Host "1. Сменить обои (ручная)" -ForegroundColor White
	Write-Host "2. Настройка конфигурации" -ForegroundColor White
	Write-Host "3. Просмотр истории обоев" -ForegroundColor White
	Write-Host "4. Восстановить обои из истории" -ForegroundColor White
	Write-Host "5. Тест соединения с API" -ForegroundColor White
	Write-Host "0. Выход" -ForegroundColor Yellow
	Write-Host ""
}

function Start-WallpaperChange {
	Write-Host "Запуск смены обоев..." -ForegroundColor Yellow
	& "$PSScriptRoot\Unsplash-BG.ps1"
	Read-Host "Нажмите Enter для продолжения"
}

function Start-Configuration {
	Write-Host "Запуск конфигуратора..." -ForegroundColor Yellow
	& "$PSScriptRoot\Config-Manager.ps1"
}

function Show-History {
	Write-Host "Просмотр истории обоев..." -ForegroundColor Yellow
	& "$PSScriptRoot\Unsplash-BG.ps1" -ShowHistory
	Read-Host "Нажмите Enter для продолжения"
}

function Restore-FromHistory {
	Write-Host "Восстановление обоев из истории..." -ForegroundColor Yellow
	$historyId = Read-Host "Введите ID изображения из истории"
	if ($historyId -match '^\d+$') {
		& "$PSScriptRoot\Unsplash-BG.ps1" -RestoreFromHistory $historyId
	} else {
		Write-Host "Неверный ID" -ForegroundColor Red
	}
	Read-Host "Нажмите Enter для продолжения"
}

function Test-Connection {
	Write-Host "Тестирование соединения..." -ForegroundColor Yellow
	& "$PSScriptRoot\Config-Manager.ps1"
	Read-Host "Нажмите Enter для продолжения"
}

# Основной цикл
if ($Action -eq "menu") {
	do {
		Show-Menu
		$choice = Read-Host "Выберите действие (0-5)"
		
		switch ($choice) {
			"1" { Start-WallpaperChange }
			"2" { Start-Configuration }
			"3" { Show-History }
			"4" { Restore-FromHistory }
			"5" { Test-Connection }
			"0" { 
				Write-Host "До свидания!" -ForegroundColor Green
				break
			}
			default { 
				Write-Host "Неверный выбор" -ForegroundColor Red
				Start-Sleep -Seconds 1
			}
		}
	} while ($choice -ne "0")
} else {
	# Прямой запуск
	switch ($Action.ToLower()) {
		"wallpaper" { Start-WallpaperChange }
		"config" { Start-Configuration }
		"history" { Show-History }
		default { 
			Write-Host "Неизвестное действие: $Action" -ForegroundColor Red
			Write-Host "Доступные действия: wallpaper, config, history" -ForegroundColor Yellow
		}
	}
}
