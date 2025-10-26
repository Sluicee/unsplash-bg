#Requires -Version 5.1

<#
.SYNOPSIS
	Unsplash Background Changer - Configuration Manager
	
.DESCRIPTION
	Интерактивный конфигуратор для настройки всех параметров Unsplash Background Changer
	
.EXAMPLE
	.\Config-Manager.ps1
#>

# Загрузка конфигурации
$ConfigPath = "$PSScriptRoot\config.json"
$Config = @{}

if (Test-Path $ConfigPath) {
	try {
		$Config = Get-Content $ConfigPath -Raw | ConvertFrom-Json -AsHashtable
	} catch {
		Write-Warning "Ошибка загрузки конфигурации: $($_.Exception.Message)"
		$Config = @{}
	}
}

# Установка значений по умолчанию
$defaultConfig = @{
	unsplash = @{
		accessKey = ""
		apiUrl = "https://api.unsplash.com"
		defaultCategory = "nature"
		defaultWidth = 1920
		defaultHeight = 1080
	}
	download = @{
		tempPath = "$env:TEMP\UnsplashBG"
		keepImages = $false
		maxCacheSize = 10
	}
	wallpaper = @{
		style = "fill"
		position = "center"
	}
	autoChange = @{
		enabled = $false
		intervalMinutes = 30
		runAtStartup = $false
	}
	taskScheduler = @{
		taskName = "UnsplashBackgroundChanger"
		enabled = $false
	}
	history = @{
		maxEntries = 50
		keepFiles = $true
		historyFile = "history.json"
	}
	logging = @{
		enabled = $true
		logFile = "unsplash-bg.log"
		logLevel = "INFO"
	}
}

# Объединяем с дефолтными значениями
foreach ($key in $defaultConfig.Keys) {
	if (!$Config.ContainsKey($key)) {
		$Config[$key] = $defaultConfig[$key]
	}
}

# Функция сохранения конфигурации
function Save-Config {
	try {
		$Config | ConvertTo-Json -Depth 3 | Set-Content $ConfigPath
		Write-Host "Конфигурация сохранена!" -ForegroundColor Green
		return $true
	}
	catch {
		Write-Host "ОШИБКА при сохранении: $($_.Exception.Message)" -ForegroundColor Red
		return $false
	}
}

# Функция отображения меню
function Show-Menu {
	Clear-Host
	Write-Host "=== Unsplash Background Changer - Configuration ===" -ForegroundColor Cyan
	Write-Host ""
	Write-Host "1. API Settings (Access Key)" -ForegroundColor White
	Write-Host "2. Display Settings (Resolution, Category)" -ForegroundColor White
	Write-Host "3. Wallpaper Style (Fill/Fit/Stretch/Center/Tile)" -ForegroundColor White
	Write-Host "4. Auto-change Settings (Enable/Interval)" -ForegroundColor White
	Write-Host "5. Task Scheduler Setup" -ForegroundColor White
	Write-Host "6. History Settings (Max cache, Keep images)" -ForegroundColor White
	Write-Host "7. View/Restore History" -ForegroundColor White
	Write-Host "8. Test Connection" -ForegroundColor White
	Write-Host "9. Save & Exit" -ForegroundColor White
	Write-Host "0. Exit without saving" -ForegroundColor Yellow
	Write-Host ""
}

# Функция настройки API
function Edit-ApiSettings {
	Clear-Host
	Write-Host "=== API Settings ===" -ForegroundColor Cyan
	Write-Host ""
	Write-Host "Текущий API ключ: " -NoNewline
	if ([string]::IsNullOrEmpty($Config.unsplash.accessKey)) {
		Write-Host "НЕ НАСТРОЕН" -ForegroundColor Red
	} else {
		Write-Host "***" + $Config.unsplash.accessKey.Substring($Config.unsplash.accessKey.Length - 4) -ForegroundColor Green
	}
	Write-Host ""
	Write-Host "Для получения API ключа:"
	Write-Host "1. Перейдите на https://unsplash.com/developers" -ForegroundColor Blue
	Write-Host "2. Создайте новое приложение"
	Write-Host "3. Скопируйте Access Key"
	Write-Host ""
	
	$choice = Read-Host "Введите новый API ключ (или Enter для пропуска)"
	if (![string]::IsNullOrEmpty($choice)) {
		$Config.unsplash.accessKey = $choice
		Write-Host "API ключ обновлен!" -ForegroundColor Green
	}
	
	Read-Host "Нажмите Enter для продолжения"
}

# Функция настройки дисплея
function Edit-DisplaySettings {
	Clear-Host
	Write-Host "=== Display Settings ===" -ForegroundColor Cyan
	Write-Host ""
	
	# Текущие настройки
	Write-Host "Текущие настройки:"
	Write-Host "Категория: $($Config.unsplash.defaultCategory)" -ForegroundColor White
	Write-Host "Разрешение: $($Config.unsplash.defaultWidth)x$($Config.unsplash.defaultHeight)" -ForegroundColor White
	Write-Host ""
	
	# Настройка категории
	Write-Host "Доступные категории:"
	$categories = @("nature", "city", "landscape", "abstract", "minimal", "architecture", "animals", "food", "people", "technology")
	foreach ($i in 0..($categories.Length - 1)) {
		Write-Host "$($i + 1). $($categories[$i])" -ForegroundColor Gray
	}
	Write-Host ""
	
	$catChoice = Read-Host "Выберите категорию (1-$($categories.Length)) или введите свою"
	if ($catChoice -match '^\d+$' -and [int]$catChoice -ge 1 -and [int]$catChoice -le $categories.Length) {
		$Config.unsplash.defaultCategory = $categories[[int]$catChoice - 1]
	} elseif (![string]::IsNullOrEmpty($catChoice)) {
		$Config.unsplash.defaultCategory = $catChoice
	}
	
	# Настройка разрешения
	Write-Host ""
	Write-Host "Настройка разрешения:"
	Write-Host "1. 1920x1080 (Full HD)"
	Write-Host "2. 2560x1440 (2K)"
	Write-Host "3. 3840x2160 (4K)"
	Write-Host "4. Определить автоматически"
	Write-Host "5. Ввести вручную"
	Write-Host ""
	
	$resChoice = Read-Host "Выберите разрешение (1-5)"
	switch ($resChoice) {
		"1" { $Config.unsplash.defaultWidth = 1920; $Config.unsplash.defaultHeight = 1080 }
		"2" { $Config.unsplash.defaultWidth = 2560; $Config.unsplash.defaultHeight = 1440 }
		"3" { $Config.unsplash.defaultWidth = 3840; $Config.unsplash.defaultHeight = 2160 }
		"4" {
			try {
				Add-Type -AssemblyName System.Windows.Forms
				$screen = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
				$Config.unsplash.defaultWidth = $screen.Width
				$Config.unsplash.defaultHeight = $screen.Height
				Write-Host "Автоматически определено: $($screen.Width)x$($screen.Height)" -ForegroundColor Green
			}
			catch {
				Write-Host "Не удалось определить разрешение автоматически" -ForegroundColor Yellow
			}
		}
		"5" {
			$width = Read-Host "Введите ширину"
			$height = Read-Host "Введите высоту"
			if ($width -match '^\d+$' -and $height -match '^\d+$') {
				$Config.unsplash.defaultWidth = [int]$width
				$Config.unsplash.defaultHeight = [int]$height
			}
		}
	}
	
	Write-Host ""
	Write-Host "Настройки обновлены:" -ForegroundColor Green
	Write-Host "Категория: $($Config.unsplash.defaultCategory)"
	Write-Host "Разрешение: $($Config.unsplash.defaultWidth)x$($Config.unsplash.defaultHeight)"
	
	Read-Host "Нажмите Enter для продолжения"
}

# Функция настройки стиля обоев
function Edit-WallpaperStyle {
	Clear-Host
	Write-Host "=== Wallpaper Style ===" -ForegroundColor Cyan
	Write-Host ""
	Write-Host "Текущий стиль: $($Config.wallpaper.style)" -ForegroundColor White
	Write-Host ""
	
	$styles = @{
		"1" = @{ Name = "Fill"; Description = "Заполнить экран (обрезание)" }
		"2" = @{ Name = "Fit"; Description = "Поместить в экран (без обрезания)" }
		"3" = @{ Name = "Stretch"; Description = "Растянуть на весь экран" }
		"4" = @{ Name = "Center"; Description = "По центру" }
		"5" = @{ Name = "Tile"; Description = "Мозаика" }
	}
	
	foreach ($key in $styles.Keys) {
		$style = $styles[$key]
		$current = if ($Config.wallpaper.style -eq $style.Name) { " (текущий)" } else { "" }
		Write-Host "$key. $($style.Name) - $($style.Description)$current" -ForegroundColor Gray
	}
	Write-Host ""
	
	$choice = Read-Host "Выберите стиль (1-5)"
	if ($styles.ContainsKey($choice)) {
		$Config.wallpaper.style = $styles[$choice].Name.ToLower()
		Write-Host "Стиль обоев установлен: $($styles[$choice].Name)" -ForegroundColor Green
	}
	
	Read-Host "Нажмите Enter для продолжения"
}

# Функция настройки автозамены
function Edit-AutoChangeSettings {
	Clear-Host
	Write-Host "=== Auto-change Settings ===" -ForegroundColor Cyan
	Write-Host ""
	
	Write-Host "Текущие настройки:"
	Write-Host "Автозамена: $(if ($Config.autoChange.enabled) { 'Включена' } else { 'Отключена' })" -ForegroundColor White
	Write-Host "Интервал: $($Config.autoChange.intervalMinutes) минут" -ForegroundColor White
	Write-Host "Запуск при старте: $(if ($Config.autoChange.runAtStartup) { 'Да' } else { 'Нет' })" -ForegroundColor White
	Write-Host ""
	
	# Включение/отключение
	$enableChoice = Read-Host "Включить автозамену обоев? (y/n)"
	if ($enableChoice -eq "y" -or $enableChoice -eq "Y") {
		$Config.autoChange.enabled = $true
		
		# Настройка интервала
		Write-Host ""
		Write-Host "Настройка интервала:"
		Write-Host "1. 15 минут"
		Write-Host "2. 30 минут"
		Write-Host "3. 1 час"
		Write-Host "4. 2 часа"
		Write-Host "5. 6 часов"
		Write-Host "6. 12 часов"
		Write-Host "7. 24 часа"
		Write-Host "8. Ввести вручную"
		Write-Host ""
		
		$intervalChoice = Read-Host "Выберите интервал (1-8)"
		switch ($intervalChoice) {
			"1" { $Config.autoChange.intervalMinutes = 15 }
			"2" { $Config.autoChange.intervalMinutes = 30 }
			"3" { $Config.autoChange.intervalMinutes = 60 }
			"4" { $Config.autoChange.intervalMinutes = 120 }
			"5" { $Config.autoChange.intervalMinutes = 360 }
			"6" { $Config.autoChange.intervalMinutes = 720 }
			"7" { $Config.autoChange.intervalMinutes = 1440 }
			"8" {
				$customInterval = Read-Host "Введите интервал в минутах"
				if ($customInterval -match '^\d+$') {
					$Config.autoChange.intervalMinutes = [int]$customInterval
				}
			}
		}
		
		# Запуск при старте
		$startupChoice = Read-Host "Запускать при старте системы? (y/n)"
		$Config.autoChange.runAtStartup = ($startupChoice -eq "y" -or $startupChoice -eq "Y")
		
		Write-Host "Автозамена настроена!" -ForegroundColor Green
	} else {
		$Config.autoChange.enabled = $false
		Write-Host "Автозамена отключена" -ForegroundColor Yellow
	}
	
	Read-Host "Нажмите Enter для продолжения"
}

# Функция настройки планировщика задач
function Setup-TaskScheduler {
	Clear-Host
	Write-Host "=== Task Scheduler Setup ===" -ForegroundColor Cyan
	Write-Host ""
	
	$taskName = $Config.taskScheduler.taskName
	$taskExists = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
	
	Write-Host "Текущий статус:"
	if ($taskExists) {
		Write-Host "Задача '$taskName' существует" -ForegroundColor Green
		$taskInfo = Get-ScheduledTaskInfo -TaskName $taskName
		Write-Host "Последний запуск: $($taskInfo.LastRunTime)"
		Write-Host "Следующий запуск: $($taskInfo.NextRunTime)"
	} else {
		Write-Host "Задача '$taskName' не найдена" -ForegroundColor Yellow
	}
	Write-Host ""
	
	Write-Host "Доступные действия:"
	Write-Host "1. Создать/обновить задачу"
	Write-Host "2. Удалить задачу"
	Write-Host "3. Просмотреть детали задачи"
	Write-Host "4. Вернуться в меню"
	Write-Host ""
	
	$choice = Read-Host "Выберите действие (1-4)"
	
	switch ($choice) {
		"1" {
			if (!$Config.autoChange.enabled) {
				Write-Host "Сначала включите автозамену в настройках!" -ForegroundColor Red
				Read-Host "Нажмите Enter для продолжения"
				return
			}
			
			try {
				# Удаляем существующую задачу
				if ($taskExists) {
					Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
				}
				
				# Создаем новую задачу
				$action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$PSScriptRoot\Unsplash-BG.ps1`" -Schedule"
				$trigger = New-ScheduledTaskTrigger -RepetitionInterval (New-TimeSpan -Minutes $Config.autoChange.intervalMinutes) -RepetitionDuration (New-TimeSpan -Days 365) -At (Get-Date)
				
				if ($Config.autoChange.runAtStartup) {
					$startupTrigger = New-ScheduledTaskTrigger -AtStartup
					$trigger = @($trigger, $startupTrigger)
				}
				
				$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
				$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType InteractiveToken
				
				Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Description "Unsplash Background Changer - автоматическая смена обоев"
				
				$Config.taskScheduler.enabled = $true
				Write-Host "Задача планировщика создана!" -ForegroundColor Green
			}
			catch {
				Write-Host "ОШИБКА при создании задачи: $($_.Exception.Message)" -ForegroundColor Red
			}
		}
		"2" {
			if ($taskExists) {
				try {
					Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
					$Config.taskScheduler.enabled = $false
					Write-Host "Задача удалена!" -ForegroundColor Green
				}
				catch {
					Write-Host "ОШИБКА при удалении задачи: $($_.Exception.Message)" -ForegroundColor Red
				}
			} else {
				Write-Host "Задача не найдена" -ForegroundColor Yellow
			}
		}
		"3" {
			if ($taskExists) {
				Get-ScheduledTask -TaskName $taskName | Get-ScheduledTaskInfo | Format-List
			} else {
				Write-Host "Задача не найдена" -ForegroundColor Yellow
			}
		}
	}
	
	Read-Host "Нажмите Enter для продолжения"
}

# Функция настройки истории
function Edit-HistorySettings {
	Clear-Host
	Write-Host "=== History Settings ===" -ForegroundColor Cyan
	Write-Host ""
	
	Write-Host "Текущие настройки:"
	Write-Host "Максимум записей: $($Config.history.maxEntries)" -ForegroundColor White
	Write-Host "Сохранять файлы: $(if ($Config.history.keepFiles) { 'Да' } else { 'Нет' })" -ForegroundColor White
	Write-Host ""
	
	# Настройка лимита записей
	$maxEntries = Read-Host "Введите максимальное количество записей в истории (текущее: $($Config.history.maxEntries))"
	if ($maxEntries -match '^\d+$' -and [int]$maxEntries -gt 0) {
		$Config.history.maxEntries = [int]$maxEntries
		Write-Host "Лимит записей обновлен: $maxEntries" -ForegroundColor Green
	}
	
	# Настройка сохранения файлов
	$keepFilesChoice = Read-Host "Сохранять файлы изображений? (y/n)"
	if ($keepFilesChoice -eq "y" -or $keepFilesChoice -eq "Y") {
		$Config.history.keepFiles = $true
	} else {
		$Config.history.keepFiles = $false
	}
	
	Write-Host "Настройки истории обновлены!" -ForegroundColor Green
	Read-Host "Нажмите Enter для продолжения"
}

# Функция просмотра истории
function Show-History {
	Clear-Host
	Write-Host "=== View/Restore History ===" -ForegroundColor Cyan
	Write-Host ""
	
	$historyFile = "$PSScriptRoot\history.json"
	if (!(Test-Path $historyFile)) {
		Write-Host "История пуста" -ForegroundColor Yellow
		Read-Host "Нажмите Enter для продолжения"
		return
	}
	
	try {
		$history = Get-Content $historyFile -Raw | ConvertFrom-Json
		if ($history.Count -eq 0) {
			Write-Host "История пуста" -ForegroundColor Yellow
			Read-Host "Нажмите Enter для продолжения"
			return
		}
		
		Write-Host "История обоев (последние 20 записей):" -ForegroundColor White
		Write-Host "ID`tДата`t`t`tКатегория`tОписание" -ForegroundColor Gray
		Write-Host ("-" * 80) -ForegroundColor Gray
		
		$recentHistory = $history | Select-Object -Last 20 | Sort-Object date -Descending
		foreach ($entry in $recentHistory) {
			$description = if ($entry.description.Length -gt 30) { 
				$entry.description.Substring(0, 30) + "..." 
			} else { 
				$entry.description 
			}
			Write-Host "$($entry.id)`t$($entry.date)`t$($entry.category)`t$description" -ForegroundColor White
		}
		
		Write-Host ""
		$restoreChoice = Read-Host "Введите ID для восстановления обоев (или Enter для пропуска)"
		if ($restoreChoice -match '^\d+$') {
			$entry = $history | Where-Object { $_.id -eq [long]$restoreChoice }
			if ($entry) {
				if (Test-Path $entry.imagePath) {
					Write-Host "Восстановление обоев..." -ForegroundColor Yellow
					& "$PSScriptRoot\Unsplash-BG.ps1" -RestoreFromHistory $restoreChoice
					Write-Host "Обои восстановлены!" -ForegroundColor Green
				} else {
					Write-Host "Файл изображения не найден: $($entry.imagePath)" -ForegroundColor Red
				}
			} else {
				Write-Host "Запись с ID $restoreChoice не найдена" -ForegroundColor Red
			}
		}
	}
	catch {
		Write-Host "ОШИБКА при чтении истории: $($_.Exception.Message)" -ForegroundColor Red
	}
	
	Read-Host "Нажмите Enter для продолжения"
}

# Функция тестирования соединения
function Test-UnsplashConnection {
	Clear-Host
	Write-Host "=== Test Connection ===" -ForegroundColor Cyan
	Write-Host ""
	
	if ([string]::IsNullOrEmpty($Config.unsplash.accessKey)) {
		Write-Host "API ключ не настроен!" -ForegroundColor Red
		Read-Host "Нажмите Enter для продолжения"
		return
	}
	
	Write-Host "Тестирование соединения с Unsplash API..." -ForegroundColor Yellow
	
	try {
		$apiUrl = "$($Config.unsplash.apiUrl)/photos/random"
		$headers = @{
			"Authorization" = "Client-ID $($Config.unsplash.accessKey)"
			"Accept-Version" = "v1"
		}
		
		$response = Invoke-RestMethod -Uri $apiUrl -Headers $headers -Method Get
		
		if ($response) {
			Write-Host "Соединение успешно!" -ForegroundColor Green
			Write-Host "Получено изображение: $($response.description ?? $response.alt_description ?? 'Без описания')" -ForegroundColor White
			Write-Host "Автор: $($response.user.name)" -ForegroundColor Gray
			Write-Host "URL: $($response.urls.regular)" -ForegroundColor Blue
		} else {
			Write-Host "Неожиданный ответ от API" -ForegroundColor Red
		}
	}
	catch {
		if ($_.Exception.Response) {
			$statusCode = $_.Exception.Response.StatusCode.value__
			switch ($statusCode) {
				401 { Write-Host "ОШИБКА: Неверный API ключ (401)" -ForegroundColor Red }
				403 { Write-Host "ОШИБКА: Доступ запрещен (403)" -ForegroundColor Red }
				429 { Write-Host "ОШИБКА: Превышен лимит запросов (429)" -ForegroundColor Red }
				default { Write-Host "ОШИБКА: HTTP $statusCode" -ForegroundColor Red }
			}
		} else {
			Write-Host "ОШИБКА: $($_.Exception.Message)" -ForegroundColor Red
		}
	}
	
	Read-Host "Нажмите Enter для продолжения"
}

# Основной цикл меню
do {
	Show-Menu
	$choice = Read-Host "Выберите опцию (0-9)"
	
	switch ($choice) {
		"1" { Edit-ApiSettings }
		"2" { Edit-DisplaySettings }
		"3" { Edit-WallpaperStyle }
		"4" { Edit-AutoChangeSettings }
		"5" { Setup-TaskScheduler }
		"6" { Edit-HistorySettings }
		"7" { Show-History }
		"8" { Test-UnsplashConnection }
		"9" { 
			if (Save-Config) {
				Write-Host "Конфигурация сохранена. До свидания!" -ForegroundColor Green
				break
			}
		}
		"0" { 
			Write-Host "Выход без сохранения. До свидания!" -ForegroundColor Yellow
			break
		}
		default { 
			Write-Host "Неверный выбор. Попробуйте снова." -ForegroundColor Red
			Start-Sleep -Seconds 1
		}
	}
} while ($choice -ne "9" -and $choice -ne "0")
