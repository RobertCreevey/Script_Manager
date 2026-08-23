# Type: Action
# Description: Prints the current date/time (custom format as first arg) and copies it when 'clip' is supplied.
param($Config, [array]$Arguments)
$Format = if ($Arguments -and $Arguments[0] -ne "clip") { $Arguments[0] } else { "yyyy-MM-dd HH:mm:ss" }
$Stamp = Get-Date -Format $Format
Write-Host $Stamp -ForegroundColor Cyan
if ($Arguments -contains "clip") { Set-Clipboard -Value $Stamp ; Write-Host "[now] Copied to clipboard." -ForegroundColor Gray }
