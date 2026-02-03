try {
    $taskName = 'UnsplashBackgroundChanger'
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
    Write-Host 'Task removed successfully!' -ForegroundColor Green
} catch {
    Write-Host "Error removing task: $($_.Exception.Message)" -ForegroundColor Red
}
