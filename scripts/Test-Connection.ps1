#Requires -Version 5.1

<#
.SYNOPSIS
	Checks the Unsplash API key and network access using config.json.
#>

try {
	$configPath = Join-Path (Split-Path $PSScriptRoot -Parent) 'config.json'
	if (!(Test-Path $configPath)) {
		Write-Host "config.json not found. Run Setup.bat first." -ForegroundColor Red
		exit 1
	}

	$config = Get-Content $configPath -Raw | ConvertFrom-Json
	if ([string]::IsNullOrWhiteSpace($config.unsplash.accessKey)) {
		Write-Host "API key not configured!" -ForegroundColor Red
		exit 1
	}

	[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

	$apiUrl = if ($config.unsplash.apiUrl) { $config.unsplash.apiUrl } else { "https://api.unsplash.com" }
	$uri = "$($apiUrl.TrimEnd('/'))/photos/random"
	$headers = @{
		"Authorization" = "Client-ID $($config.unsplash.accessKey)"
		"Accept-Version" = "v1"
	}

	$response = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get
	Write-Host "Connection successful!" -ForegroundColor Green
	$description = if ($response.description) { $response.description } elseif ($response.alt_description) { $response.alt_description } else { "Unsplash Image" }
	Write-Host "Image: $description" -ForegroundColor White
	Write-Host "Author: $($response.user.name)" -ForegroundColor Gray
} catch {
	$statusCode = $null
	if ($_.Exception.Response) { $statusCode = $_.Exception.Response.StatusCode.value__ }
	switch ($statusCode) {
		401 { Write-Host "ERROR: Invalid API key (401)" -ForegroundColor Red }
		403 { Write-Host "ERROR: Access denied (403)" -ForegroundColor Red }
		429 { Write-Host "ERROR: Rate limit exceeded (429)" -ForegroundColor Red }
		default { Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red }
	}
	exit 1
}
