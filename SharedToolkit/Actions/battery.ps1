# Type: Action
# Description: Reports the local battery status and estimated charge remaining.
param($Config, [array]$Arguments)
$B = Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue
if (-not $B) { Write-Host "[battery] No battery detected (AC powered)." -ForegroundColor Yellow ; return }
$B | ForEach-Object {
    $State = if ($_.BatteryStatus -eq 2) { "Charging" } else { "Discharging" }
    Write-Host "Battery: $State - $($_.EstimatedChargeRemaining)%" -ForegroundColor Cyan
}
