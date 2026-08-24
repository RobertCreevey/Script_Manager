# Type: Action
# Description: Displays recent framework events from the in-memory ring buffer and the persistent event log file.
param($Config, [array]$Arguments)
$Count = if ($Arguments[0] -and $Arguments[0] -match '^\d+$') { [int]$Arguments[0] } else { 20 }
$C = Get-ToolkitColors
Write-Host "$($C.Sys)=== Recent Events (ring buffer, last $Count) ===$($C.Reset)"
if ($global:ToolEvents.Count -eq 0) { Write-Host "(no events yet)" -ForegroundColor Gray }
$global:ToolEvents | Select-Object -Last $Count | ForEach-Object {
    Write-Host "$($C.Info)[$($_.Time)] [$($_.Context)] $($_.Name)$(if ($_.Data) { ': ' + $_.Data })$($C.Reset)"
}
Write-Host "$($C.Sys)=== Persisted log tail ===$($C.Reset)"
if (Test-Path $global:ToolEventLog) { Get-Content $global:ToolEventLog -Tail $Count } else { Write-Host "(no log file)" -ForegroundColor Gray }

