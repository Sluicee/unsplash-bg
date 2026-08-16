#Requires -Version 5.1

<#
.SYNOPSIS
	Removes the Windows Task Scheduler task created by Create-Task.ps1.
#>

try {
	$configPath = Join-Path (Split-Path $PSScriptRoot -Parent) 'config.json'
	$taskName = 'UnsplashBackgroundChanger'
	if (Test-Path $configPath) {
		$config = Get-Content $configPath -Raw | ConvertFrom-Json
		if ($config.taskScheduler.taskName) { $taskName = $config.taskScheduler.taskName }
	}

	if (-not (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue)) {
		Write-Host "Task '$taskName' not found - nothing to remove." -ForegroundColor Yellow
		return
	}

	Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
	Write-Host "Task '$taskName' removed successfully!" -ForegroundColor Green
} catch {
	Write-Host "Error removing task: $($_.Exception.Message)" -ForegroundColor Red
	exit 1
}
