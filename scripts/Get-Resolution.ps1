#Requires -Version 5.1

<#
.SYNOPSIS
	Prints the primary display resolution as "<width> <height>".

.DESCRIPTION
	Used by Setup.bat auto-detect. Replaces wmic, which is deprecated and no
	longer present by default on recent Windows 11 builds.
#>

$width = 0
$height = 0

try {
	$controller = Get-CimInstance -ClassName Win32_VideoController -ErrorAction Stop |
		Where-Object { $_.CurrentHorizontalResolution -gt 0 } |
		Select-Object -First 1
	if ($controller) {
		$width = [int]$controller.CurrentHorizontalResolution
		$height = [int]$controller.CurrentVerticalResolution
	}
} catch { }

if ($width -le 0) {
	try {
		Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
		$bounds = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
		$width = $bounds.Width
		$height = $bounds.Height
	} catch { }
}

if ($width -le 0 -or $height -le 0) {
	$width = 1920
	$height = 1080
}

Write-Output "$width $height"
