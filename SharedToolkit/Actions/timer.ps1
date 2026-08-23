# Type: Action
# Description: Waits N seconds then fires a toast + beep reminder with the supplied message.
param($Config, [array]$Arguments)
$Secs = if ($Arguments[0] -match '^\d+$') { [int]$Arguments[0] } else { 0 }
$Msg = if ($Arguments[1]) { ($Arguments[1..($Arguments.Length-1)] -join " ") } else { "Timer finished" }
if ($Secs -le 0) { Write-Host "[ERROR] Usage: timer <seconds> <message>" -ForegroundColor Red ; return }
Write-Host "[timer] Waiting $Secs s for: $Msg" -ForegroundColor Yellow
Start-Sleep -Seconds $Secs
& "$global:SharedToolkitPath\Actions\toast.ps1" -Config $Config -Arguments @("Timer", $Msg)
[Console]::Beep(880, 400)
& "$global:SharedToolkitPath\Actions\log.ps1" -Config $Config -Arguments @("Timer alert: $Msg")
