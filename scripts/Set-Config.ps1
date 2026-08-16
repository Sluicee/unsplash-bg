#Requires -Version 5.1

<#
.SYNOPSIS
	Sets a single value in config.json.

.DESCRIPTION
	Called by Setup.bat instead of inline PowerShell: values arrive as real
	arguments, so quotes or special characters in user input cannot break
	(or inject into) the command line.

.EXAMPLE
	.\Set-Config.ps1 -Path unsplash.accessKey -Value "abc123"

.EXAMPLE
	.\Set-Config.ps1 -Path autoChange.intervalMinutes -Value 30 -Type int
#>

param(
	[Parameter(Mandatory = $true)][string]$Path,
	[Parameter(Mandatory = $true)][AllowEmptyString()][string]$Value,
	[ValidateSet('string', 'int', 'bool')][string]$Type = 'string'
)

try {
	$rootPath = Split-Path $PSScriptRoot -Parent
	$configPath = Join-Path $rootPath 'config.json'
	$templatePath = Join-Path $rootPath 'config.json.template'

	if (!(Test-Path $configPath)) {
		if (Test-Path $templatePath) {
			Copy-Item $templatePath $configPath
		} else {
			throw "config.json not found and no template available"
		}
	}

	$config = Get-Content $configPath -Raw | ConvertFrom-Json

	$typedValue = switch ($Type) {
		'int' {
			$parsed = 0
			if (-not [int]::TryParse($Value, [ref]$parsed)) { throw "'$Value' is not a number" }
			$parsed
		}
		'bool' { $Value -in @('true', 'True', '1', 'y', 'Y', 'yes') }
		default { $Value }
	}

	$segments = $Path.Split('.')
	$node = $config
	for ($i = 0; $i -lt $segments.Count - 1; $i++) {
		if ($null -eq $node.$($segments[$i])) {
			$node | Add-Member -NotePropertyName $segments[$i] -NotePropertyValue ([PSCustomObject]@{}) -Force
		}
		$node = $node.$($segments[$i])
	}
	$node | Add-Member -NotePropertyName $segments[-1] -NotePropertyValue $typedValue -Force

	# UTF-8 without BOM: the Linux scripts read the same file with jq, which chokes on a BOM
	$json = $config | ConvertTo-Json -Depth 5
	[System.IO.File]::WriteAllText($configPath, $json, (New-Object System.Text.UTF8Encoding($false)))

	Write-Host "$Path = $typedValue" -ForegroundColor Green
} catch {
	Write-Host "Error updating config: $($_.Exception.Message)" -ForegroundColor Red
	exit 1
}
