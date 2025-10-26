#Requires -Version 5.1

<#
.SYNOPSIS
	Unsplash Background Changer - PowerShell скрипт для установки случайных обоев с Unsplash
	
.DESCRIPTION
	Этот скрипт загружает случайные изображения с Unsplash API и устанавливает их как фон рабочего стола
	
.PARAMETER Category
	Категория изображений для поиска (по умолчанию: nature)
	
.PARAMETER Width
	Ширина изображения (по умолчанию: 1920)
	
.PARAMETER Height
	Высота изображения (по умолчанию: 1080)
	
.PARAMETER Schedule
	Режим автоматической работы (без интерактива)
	
.PARAMETER RestoreFromHistory
	ID изображения из истории для восстановления
	
.PARAMETER ShowHistory
	Показать список истории изображений
	
.EXAMPLE
	.\Unsplash-BG.ps1
	
.EXAMPLE
	.\Unsplash-BG.ps1 -Category "city" -Width 2560 -Height 1440
	
.EXAMPLE
	.\Unsplash-BG.ps1 -Schedule
	
.EXAMPLE
	.\Unsplash-BG.ps1 -RestoreFromHistory 5
	
.EXAMPLE
	.\Unsplash-BG.ps1 -ShowHistory
#>

param(
	[string]$Category = "nature",
	[int]$Width = 1920,
	[int]$Height = 1080,
	[switch]$Schedule,
	[int]$RestoreFromHistory = -1,
	[switch]$ShowHistory
)

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
$Config.UnsplashAPI = $Config.unsplash.apiUrl ?? "https://api.unsplash.com"
$Config.AccessKey = $Config.unsplash.accessKey ?? ""
$Config.DownloadPath = if ($Config.download.tempPath) { 
	$Config.download.tempPath -replace '\$env:TEMP', $env:TEMP 
} else { 
	"$env:TEMP\UnsplashBG" 
}
$Config.LogFile = $Config.logging.logFile ?? "$PSScriptRoot\unsplash-bg.log"
$Config.HistoryFile = $Config.history.historyFile ?? "$PSScriptRoot\history.json"

# Создаем папку для загрузок если не существует
if (!(Test-Path $Config.DownloadPath)) {
	New-Item -ItemType Directory -Path $Config.DownloadPath -Force | Out-Null
}

# Функция логирования
function Write-Log {
	param([string]$Message)
	$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
	$logEntry = "[$timestamp] $Message"
	Write-Host $logEntry
	Add-Content -Path $Config.LogFile -Value $logEntry
}

# Функция получения случайного изображения
function Get-RandomImage {
	param([string]$Category, [int]$Width, [int]$Height)
	
	try {
		Write-Log "Запрос случайного изображения: Category=$Category, Size=${Width}x${Height}"
		
		if ([string]::IsNullOrEmpty($Config.AccessKey)) {
			Write-Log "ОШИБКА: API ключ не настроен. Используйте Config.exe для настройки."
			return $null
		}
		
		# Формируем URL для запроса
		$apiUrl = "$($Config.UnsplashAPI)/photos/random"
		$queryParams = @{
			query = $Category
			orientation = "landscape"
			w = $Width
			h = $Height
		}
		
		$url = $apiUrl + "?" + (($queryParams.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join "&")
		
		# Заголовки для API
		$headers = @{
			"Authorization" = "Client-ID $($Config.AccessKey)"
			"Accept-Version" = "v1"
		}
		
		Write-Log "Отправка запроса к Unsplash API..."
		$response = Invoke-RestMethod -Uri $url -Headers $headers -Method Get
		
		if ($response -and $response.urls) {
			# Получаем URL изображения нужного размера
			$imageUrl = $response.urls.raw
			$imageId = $response.id
			$imageDescription = $response.description ?? $response.alt_description ?? "Unsplash Image"
			
			Write-Log "Получено изображение: $imageDescription (ID: $imageId)"
			
			# Загружаем изображение
			$fileName = "unsplash_${imageId}_${Width}x${Height}.jpg"
			$filePath = Join-Path $Config.DownloadPath $fileName
			
			Write-Log "Загрузка изображения: $imageUrl"
			Invoke-WebRequest -Uri $imageUrl -OutFile $filePath -UseBasicParsing
			
			if (Test-Path $filePath) {
				Write-Log "Изображение загружено: $filePath"
				
				# Сохраняем в историю
				Save-WallpaperHistory -ImagePath $filePath -ImageUrl $imageUrl -Category $Category -ImageId $imageId -Description $imageDescription
				
				return $filePath
			} else {
				Write-Log "ОШИБКА: Не удалось загрузить изображение"
				return $null
			}
		} else {
			Write-Log "ОШИБКА: Неверный ответ от API"
			return $null
		}
	}
	catch {
		if ($_.Exception.Response) {
			$statusCode = $_.Exception.Response.StatusCode.value__
			switch ($statusCode) {
				401 { Write-Log "ОШИБКА: Неверный API ключ (401)" }
				403 { Write-Log "ОШИБКА: Доступ запрещен (403)" }
				429 { Write-Log "ОШИБКА: Превышен лимит запросов (429)" }
				default { Write-Log "ОШИБКА: HTTP $statusCode" }
			}
		} else {
			Write-Log "ОШИБКА: $($_.Exception.Message)"
		}
		return $null
	}
}

# Функция установки обоев
function Set-Wallpaper {
	param([string]$ImagePath)
	
	try {
		Write-Log "Установка обоев: $ImagePath"
		
		if (!(Test-Path $ImagePath)) {
			Write-Log "ОШИБКА: Файл изображения не найден: $ImagePath"
			return $false
		}
		
		# Получаем стиль обоев из конфига
		$wallpaperStyle = $Config.wallpaper.style ?? "fill"
		
		# Добавляем тип для SystemParametersInfo
		Add-Type -TypeDefinition @"
			using System;
			using System.Runtime.InteropServices;
			public class Wallpaper {
				[DllImport("user32.dll", CharSet=CharSet.Auto)]
				public static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
			}
"@
		
		# Устанавливаем обои
		$result = [Wallpaper]::SystemParametersInfo(0x0014, 0, $ImagePath, 0x01)
		
		if ($result -eq 1) {
			# Обновляем реестр для стиля обоев
			$styleValue = switch ($wallpaperStyle.ToLower()) {
				"fill" { 10 }
				"fit" { 6 }
				"stretch" { 2 }
				"center" { 0 }
				"tile" { 1 }
				default { 10 }
			}
			
			Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "WallpaperStyle" -Value $styleValue -Force
			Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "TileWallpaper" -Value 0 -Force
			
			# Обновляем рабочий стол
			[Wallpaper]::SystemParametersInfo(0x0014, 0, $ImagePath, 0x01)
			
			Write-Log "Обои успешно установлены (стиль: $wallpaperStyle)"
			return $true
		} else {
			Write-Log "ОШИБКА: Не удалось установить обои"
			return $false
		}
	}
	catch {
		Write-Log "ОШИБКА при установке обоев: $($_.Exception.Message)"
		return $false
	}
}

# Функция сохранения в историю
function Save-WallpaperHistory {
	param(
		[string]$ImagePath,
		[string]$ImageUrl,
		[string]$Category,
		[string]$ImageId,
		[string]$Description
	)
	
	try {
		$history = @()
		
		# Загружаем существующую историю
		if (Test-Path $Config.HistoryFile) {
			$history = Get-Content $Config.HistoryFile -Raw | ConvertFrom-Json
		}
		
		# Добавляем новую запись
		$newEntry = @{
			id = [DateTime]::Now.Ticks
			date = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
			imagePath = $ImagePath
			imageUrl = $ImageUrl
			category = $Category
			imageId = $ImageId
			description = $Description
		}
		
		$history += $newEntry
		
		# Ограничиваем размер истории
		$maxEntries = $Config.history.maxEntries ?? 50
		if ($history.Count -gt $maxEntries) {
			$history = $history | Select-Object -Last $maxEntries
		}
		
		# Сохраняем историю
		$history | ConvertTo-Json -Depth 3 | Set-Content $Config.HistoryFile
		
		Write-Log "Изображение добавлено в историю (ID: $($newEntry.id))"
	}
	catch {
		Write-Log "ОШИБКА при сохранении в историю: $($_.Exception.Message)"
	}
}

# Функция получения истории
function Get-WallpaperHistory {
	param([int]$Limit = 10)
	
	try {
		if (Test-Path $Config.HistoryFile) {
			$history = Get-Content $Config.HistoryFile -Raw | ConvertFrom-Json
			return $history | Select-Object -Last $Limit | Sort-Object date -Descending
		}
		return @()
	}
	catch {
		Write-Log "ОШИБКА при чтении истории: $($_.Exception.Message)"
		return @()
	}
}

# Функция восстановления из истории
function Restore-FromHistory {
	param([long]$HistoryId)
	
	try {
		$history = Get-WallpaperHistory -Limit 1000
		$entry = $history | Where-Object { $_.id -eq $HistoryId }
		
		if ($entry) {
			if (Test-Path $entry.imagePath) {
				Write-Log "Восстановление обоев из истории: $($entry.description)"
				return Set-Wallpaper -ImagePath $entry.imagePath
			} else {
				Write-Log "ОШИБКА: Файл изображения не найден: $($entry.imagePath)"
				return $false
			}
		} else {
			Write-Log "ОШИБКА: Запись с ID $HistoryId не найдена в истории"
			return $false
		}
	}
	catch {
		Write-Log "ОШИБКА при восстановлении из истории: $($_.Exception.Message)"
		return $false
	}
}

# Функция показа истории
function Show-History {
	$history = Get-WallpaperHistory -Limit 20
	
	if ($history.Count -eq 0) {
		Write-Host "История пуста" -ForegroundColor Yellow
		return
	}
	
	Write-Host "`n=== История обоев ===" -ForegroundColor Cyan
	Write-Host "ID`tДата`t`t`tКатегория`tОписание" -ForegroundColor Gray
	Write-Host ("-" * 80) -ForegroundColor Gray
	
	foreach ($entry in $history) {
		$description = if ($entry.description.Length -gt 30) { 
			$entry.description.Substring(0, 30) + "..." 
		} else { 
			$entry.description 
		}
		Write-Host "$($entry.id)`t$($entry.date)`t$($entry.category)`t$description" -ForegroundColor White
	}
	Write-Host ""
}

# Основная логика
function Main {
	Write-Log "Запуск Unsplash Background Changer"
	
	# Обработка специальных режимов
	if ($ShowHistory) {
		Show-History
		return
	}
	
	if ($RestoreFromHistory -gt 0) {
		$success = Restore-FromHistory -HistoryId $RestoreFromHistory
		if ($success) {
			Write-Log "Обои восстановлены из истории"
		} else {
			Write-Log "Не удалось восстановить обои из истории"
		}
		return
	}
	
	# Проверяем конфигурацию
	if ([string]::IsNullOrEmpty($Config.AccessKey)) {
		Write-Log "ВНИМАНИЕ: AccessKey не настроен. Используйте Config.exe для настройки."
		if (!$Schedule) {
			Write-Host "Для настройки API ключа запустите: .\Config-Manager.ps1" -ForegroundColor Yellow
		}
		return
	}
	
	# Получаем случайное изображение
	$imagePath = Get-RandomImage -Category $Category -Width $Width -Height $Height
	
	if ($imagePath -and (Test-Path $imagePath)) {
		# Устанавливаем обои
		$success = Set-Wallpaper -ImagePath $imagePath
		
		if ($success) {
			Write-Log "Обои успешно установлены"
			if (!$Schedule) {
				Write-Host "Обои обновлены!" -ForegroundColor Green
			}
		} else {
			Write-Log "Не удалось установить обои"
		}
	} else {
		Write-Log "Не удалось получить изображение"
	}
	
	Write-Log "Завершение работы"
}

# Запуск основной функции
Main
