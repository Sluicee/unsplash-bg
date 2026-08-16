#Requires -Version 5.1

<#
.SYNOPSIS
	Registers the Windows Task Scheduler task for automatic wallpaper changes.

.DESCRIPTION
	Reads taskScheduler.taskName and autoChange.intervalMinutes from config.json.
	Creates an at-logon trigger plus a repeating trigger for the configured interval.
	Runs as the current user - a wallpaper can only be applied inside a user session,
	so no elevation is required.
#>

try {
	$rootPath = Split-Path $PSScriptRoot -Parent
	$scriptPath = Join-Path $PSScriptRoot 'Unsplash-BG.ps1'
	$configPath = Join-Path $rootPath 'config.json'

	if (!(Test-Path $scriptPath)) {
		throw "Script not found: $scriptPath"
	}

	$taskName = 'UnsplashBackgroundChanger'
	$intervalMinutes = 0
	if (Test-Path $configPath) {
		$config = Get-Content $configPath -Raw | ConvertFrom-Json
		if ($config.taskScheduler.taskName) { $taskName = $config.taskScheduler.taskName }
		if ($config.autoChange.enabled -and $config.autoChange.intervalMinutes -gt 0) {
			$intervalMinutes = [int]$config.autoChange.intervalMinutes
		}
	}

	$action = New-ScheduledTaskAction -Execute 'powershell.exe' `
		-Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$scriptPath`" -Schedule" `
		-WorkingDirectory $rootPath

	$triggers = @(New-ScheduledTaskTrigger -AtLogOn)
	if ($intervalMinutes -gt 0) {
		# Omitting -RepetitionDuration means "repeat indefinitely"
		$triggers += New-ScheduledTaskTrigger -Once -At (Get-Date) `
			-RepetitionInterval (New-TimeSpan -Minutes $intervalMinutes)
	}

	$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
		-StartWhenAvailable -RunOnlyIfNetworkAvailable

	Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $triggers -Settings $settings -Force | Out-Null

	if ($intervalMinutes -gt 0) {
		Write-Host "Task '$taskName' created: at logon and every $intervalMinutes minutes." -ForegroundColor Green
	} else {
		Write-Host "Task '$taskName' created: at logon only (auto-change disabled in config.json)." -ForegroundColor Green
	}
} catch {
	Write-Host "Error creating task: $($_.Exception.Message)" -ForegroundColor Red
	exit 1
}
