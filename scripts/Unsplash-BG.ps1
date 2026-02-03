#Requires -Version 5.1

<#
.SYNOPSIS
	Unsplash Background Changer - Simple Version
	
.DESCRIPTION
	Simple PowerShell script for changing desktop wallpapers with Unsplash images
	
.PARAMETER Category
	Image category for search (default: nature)
	
.PARAMETER Width
	Image width (default: 1920)
	
.PARAMETER Height
	Image height (default: 1080)
	
.EXAMPLE
	.\Unsplash-BG.ps1
	
.EXAMPLE
	.\Unsplash-BG.ps1 -Category "city" -Width 2560 -Height 1440
#>

param(
	[string]$Category = "nature",
	[int]$Width = 1920,
	[int]$Height = 1080
)

# Load configuration
$ConfigPath = "$PSScriptRoot\..\config.json"
$Config = @{}

if (Test-Path $ConfigPath) {
	try {
		$Config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
	} catch {
		Write-Warning "Error loading configuration: $($_.Exception.Message)"
	}
}

# Set default values
$AccessKey = if ($Config.unsplash.accessKey) { $Config.unsplash.accessKey } else { "" }
$DownloadPath = if ($Config.download.tempPath) { 
	$Config.download.tempPath -replace '\$env:TEMP', $env:TEMP 
} else { 
	"$env:TEMP\UnsplashBG" 
}
$LogFile = if ($Config.logging.logFile) { $Config.logging.logFile } else { "$PSScriptRoot\unsplash-bg.log" }

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
	Write-Host $logEntry
	Add-Content -Path $LogFile -Value $logEntry
}

# Get random image function
function Get-RandomImage {
	param([string]$Category, [int]$Width, [int]$Height)
	
	try {
		Write-Log "Requesting random image: Category=$Category, Size=${Width}x${Height}"
		
		if ([string]::IsNullOrEmpty($AccessKey)) {
			Write-Log "ERROR: API key not configured. Use Config-Fixed.bat to configure."
			return $null
		}
		
		# Build API URL
		$apiUrl = "https://api.unsplash.com/photos/random"
		$url = "${apiUrl}?query=${Category}&orientation=landscape&w=${Width}&h=${Height}"
		
		# API headers
		$headers = @{
			"Authorization" = "Client-ID $AccessKey"
			"Accept-Version" = "v1"
		}
		
		Write-Log "Sending request to Unsplash API..."
		$response = Invoke-RestMethod -Uri $url -Headers $headers -Method Get
		
		if ($response -and $response.urls) {
			# Get image URL
			$imageUrl = $response.urls.raw
			$imageId = $response.id
			$imageDescription = if ($response.description) { $response.description } elseif ($response.alt_description) { $response.alt_description } else { "Unsplash Image" }
			
			Write-Log "Received image: $imageDescription (ID: $imageId)"
			
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
		
		# Add type for SystemParametersInfo
		Add-Type -TypeDefinition @"
			using System;
			using System.Runtime.InteropServices;
			public class Wallpaper {
				[DllImport("user32.dll", CharSet=CharSet.Auto)]
				public static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
			}
"@
		
		# Set wallpaper
		$result = [Wallpaper]::SystemParametersInfo(0x0014, 0, $ImagePath, 0x01)
		
		if ($result -eq 1) {
			# Update registry for wallpaper style
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
			
			# Update desktop
			[Wallpaper]::SystemParametersInfo(0x0014, 0, $ImagePath, 0x01)
			
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
	if ([string]::IsNullOrEmpty($AccessKey)) {
		Write-Log "WARNING: AccessKey not configured. Use Setup.bat to configure."
		Write-Host "To configure API key run: .\Setup.bat" -ForegroundColor Yellow
		return
	}
	
	# Get random image
	$imagePath = Get-RandomImage -Category $Category -Width $Width -Height $Height
	
	if ($imagePath -and (Test-Path $imagePath)) {
		# Set wallpaper
		$success = Set-Wallpaper -ImagePath $imagePath
		
		if ($success) {
			Write-Log "Wallpaper set successfully"
			Write-Host "Wallpaper updated!" -ForegroundColor Green
		} else {
			Write-Log "Failed to set wallpaper"
		}
	} else {
		Write-Log "Failed to get image"
	}
	
	Write-Log "Finished"
}

# Run main function
Main