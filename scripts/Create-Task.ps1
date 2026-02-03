try {
    $taskName = 'UnsplashBackgroundChanger'
    $scriptPath = Join-Path (Split-Path (Get-Location)) 'scripts\Unsplash-BG.ps1'
    $action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`" -Schedule"
    $trigger = New-ScheduledTaskTrigger -AtStartup
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
    Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Force
    Write-Host 'Task created successfully!' -ForegroundColor Green
} catch {
    Write-Host "Error creating task: $($_.Exception.Message)" -ForegroundColor Red
}
