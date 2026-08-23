# Type: Listener
# Description: Time sync check-in listener that announces the local system time.
param($Config, [array]$Arguments)
$Time = Get-Date -Format "HH:mm:ss"
$ContextStr = if ($Config) { $Config.IP } else { "LocalSystem" }
Write-Host "[Clock Listener] $Time  Context: $($ContextStr)" -ForegroundColor Cyan
