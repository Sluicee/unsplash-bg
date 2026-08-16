#Requires -Version 5.1

<#
.SYNOPSIS
	Unsplash Background Changer - Simple Version

.DESCRIPTION
	Simple PowerShell script for changing desktop wallpapers with Unsplash images.
	Values not passed as parameters are taken from config.json.

.PARAMETER Category
	Image category for search (default: config.json unsplash.defaultCategory, or "nature")

.PARAMETER Width
	Image width (default: config.json unsplash.defaultWidth, or 1920)

.PARAMETER Height
	Image height (default: config.json unsplash.defaultHeight, or 1080)

.PARAMETER Schedule
	Non-interactive mode: log only, no console messages. Used by the scheduled task.

.EXAMPLE
	.\Unsplash-BG.ps1

.EXAMPLE
	.\Unsplash-BG.ps1 -Category "city" -Width 2560 -Height 1440
#>

param(
	[string]$Category,
	[int]$Width,
	[int]$Height,
	[switch]$Schedule
)

# Load configuration
$RootPath = Split-Path $PSScriptRoot -Parent
$ConfigPath = Join-Path $RootPath "config.json"
$Config = $null

if (Test-Path $ConfigPath) {
	try {
		$Config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
	} catch {
		Write-Warning "Error loading configuration: $($_.Exception.Message)"
	}
}

# Resolves a config path: relative values are based on the project root, not the
# current directory, so the scheduled task writes to the same place as a manual run.
function Resolve-ConfigPath {
	param([string]$Path, [string]$Default)

	if ([string]::IsNullOrWhiteSpace($Path)) { $Path = $Default }
	$Path = $Path -replace '\$env:TEMP', $env:TEMP
	$Path = [Environment]::ExpandEnvironmentVariables($Path)
	if ([System.IO.Path]::IsPathRooted($Path)) { return $Path }
	return Join-Path $RootPath $Path
}

# Set default values (parameters win over config, config wins over hardcoded defaults)
$AccessKey = if ($Config.unsplash.accessKey) { $Config.unsplash.accessKey } else { "" }
$ApiUrl = if ($Config.unsplash.apiUrl) { $Config.unsplash.apiUrl } else { "https://api.unsplash.com" }
if (-not $PSBoundParameters.ContainsKey('Category')) {
	$Category = if ($Config.unsplash.defaultCategory) { $Config.unsplash.defaultCategory } else { "nature" }
}
if (-not $PSBoundParameters.ContainsKey('Width')) {
	$Width = if ($Config.unsplash.defaultWidth -gt 0) { [int]$Config.unsplash.defaultWidth } else { 1920 }
}
if (-not $PSBoundParameters.ContainsKey('Height')) {
	$Height = if ($Config.unsplash.defaultHeight -gt 0) { [int]$Config.unsplash.defaultHeight } else { 1080 }
}
$DownloadPath = Resolve-ConfigPath -Path $Config.download.tempPath -Default "$env:TEMP\UnsplashBG"
$LogFile = Resolve-ConfigPath -Path $Config.logging.logFile -Default "logs\unsplash-bg.log"
$KeepImages = [bool]$Config.download.keepImages
$MaxCacheSize = if ($Config.download.maxCacheSize -gt 0) { [int]$Config.download.maxCacheSize } else { 10 }

# Create download folder if not exists
if (!(Test-Path $DownloadPath)) {
	New-Item -ItemType Directory -Path $DownloadPath -Force | Out-Null
}

# Create logs folder if not exists
$LogDir = Split-Path $LogFile -Parent
if (!(Test-Path $LogDir)) {
	New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}

# Logging function
function Write-Log {
	param([string]$Message)
	$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
	$logEntry = "[$timestamp] $Message"
	if (-not $Schedule) { Write-Host $logEntry }
	Add-Content -Path $LogFile -Value $logEntry
}

# Get random image function
function Get-RandomImage {
	param([string]$Category, [int]$Width, [int]$Height)

	try {
		Write-Log "Requesting random image: Category=$Category, Size=${Width}x${Height}"

		# Build API URL
		$url = "$($ApiUrl.TrimEnd('/'))/photos/random?query=${Category}&orientation=landscape"

		# API headers
		$headers = @{
			"Authorization" = "Client-ID $AccessKey"
			"Accept-Version" = "v1"
		}

		Write-Log "Sending request to Unsplash API..."
		$response = Invoke-RestMethod -Uri $url -Headers $headers -Method Get

		if ($response -and $response.urls) {
			# urls.raw is the full-size original; imgix parameters do the actual resizing
			$imageUrl = "$($response.urls.raw)&w=${Width}&h=${Height}&fit=crop&fm=jpg&q=85"
			$imageId = $response.id
			$imageDescription = if ($response.description) { $response.description } elseif ($response.alt_description) { $response.alt_description } else { "Unsplash Image" }

			Write-Log "Received image: $imageDescription (ID: $imageId, author: $($response.user.name))"

			# Download image
			$fileName = "unsplash_${imageId}_${Width}x${Height}.jpg"
			$filePath = Join-Path $DownloadPath $fileName

			Write-Log "Downloading image: $imageUrl"
			Invoke-WebRequest -Uri $imageUrl -OutFile $filePath -UseBasicParsing

			if (Test-Path $filePath) {
				Write-Log "Image downloaded: $filePath"
				return $filePath
			} else {
				Write-Log "ERROR: Failed to download image"
				return $null
			}
		} else {
			Write-Log "ERROR: Invalid API response"
			return $null
		}
	}
	catch {
		if ($_.Exception.Response) {
			$statusCode = $_.Exception.Response.StatusCode.value__
			switch ($statusCode) {
				401 { Write-Log "ERROR: Invalid API key (401)" }
				403 { Write-Log "ERROR: Access denied (403)" }
				429 { Write-Log "ERROR: Rate limit exceeded (429)" }
				default { Write-Log "ERROR: HTTP $statusCode" }
			}
		} else {
			Write-Log "ERROR: $($_.Exception.Message)"
		}
		return $null
	}
}

# Remove old cached images. The current wallpaper file must stay on disk:
# Windows keeps referencing it by path.
function Remove-OldImages {
	param([string]$CurrentImage)

	try {
		$keep = if ($KeepImages) { $MaxCacheSize } else { 1 }
		Get-ChildItem -Path $DownloadPath -Filter "unsplash_*.jpg" -File -ErrorAction Stop |
			Sort-Object LastWriteTime -Descending |
			Select-Object -Skip $keep |
			Where-Object { $_.FullName -ne $CurrentImage } |
			Remove-Item -Force -ErrorAction SilentlyContinue
	}
	catch {
		Write-Log "WARNING: Cache cleanup failed: $($_.Exception.Message)"
	}
}

# Set wallpaper function
function Set-Wallpaper {
	param([string]$ImagePath)

	try {
		Write-Log "Setting wallpaper: $ImagePath"

		if (!(Test-Path $ImagePath)) {
			Write-Log "ERROR: Image file not found: $ImagePath"
			return $false
		}

		# Get wallpaper style from config
		$wallpaperStyle = if ($Config.wallpaper.style) { $Config.wallpaper.style } else { "fill" }

		# Add type for SystemParametersInfo (only once per session)
		if (-not ('Wallpaper' -as [type])) {
			Add-Type -TypeDefinition @"
				using System;
				using System.Runtime.InteropServices;
				public class Wallpaper {
					[DllImport("user32.dll", CharSet=CharSet.Auto)]
					public static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
				}
"@
		}

		# Update registry for wallpaper style before applying the image
		$styleValue = switch ($wallpaperStyle.ToLower()) {
			"fill" { 10 }
			"fit" { 6 }
			"stretch" { 2 }
			"center" { 0 }
			"tile" { 0 }
			default { 10 }
		}
		$tileValue = if ($wallpaperStyle.ToLower() -eq "tile") { 1 } else { 0 }

		Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "WallpaperStyle" -Value $styleValue -Force
		Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "TileWallpaper" -Value $tileValue -Force

		# SPI_SETDESKWALLPAPER = 0x0014, SPIF_UPDATEINIFILE = 0x01
		$result = [Wallpaper]::SystemParametersInfo(0x0014, 0, $ImagePath, 0x01)

		if ($result -eq 1) {
			Write-Log "Wallpaper set successfully (style: $wallpaperStyle)"
			return $true
		} else {
			Write-Log "ERROR: Failed to set wallpaper"
			return $false
		}
	}
	catch {
		Write-Log "ERROR setting wallpaper: $($_.Exception.Message)"
		return $false
	}
}

# Main logic
function Main {
	Write-Log "Starting Unsplash Background Changer"

	# Check configuration
	if ([string]::IsNullOrWhiteSpace($AccessKey)) {
		Write-Log "ERROR: AccessKey not configured. Use Setup.bat to configure."
		if (-not $Schedule) {
			Write-Host "To configure API key run: .\Setup.bat" -ForegroundColor Yellow
		}
		exit 1
	}

	# TLS 1.2 for older Windows defaults
	[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
	$ProgressPreference = 'SilentlyContinue'

	# Get random image
	$imagePath = Get-RandomImage -Category $Category -Width $Width -Height $Height

	if ($imagePath -and (Test-Path $imagePath)) {
		# Set wallpaper
		$success = Set-Wallpaper -ImagePath $imagePath

		if ($success) {
			Remove-OldImages -CurrentImage $imagePath
			if (-not $Schedule) {
				Write-Host "Wallpaper updated!" -ForegroundColor Green
			}
			Write-Log "Finished"
		} else {
			Write-Log "Failed to set wallpaper"
			exit 1
		}
	} else {
		Write-Log "Failed to get image"
		exit 1
	}
}

# Run main function
Main
