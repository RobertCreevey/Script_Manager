# Type: Action
# Description: Shows or controls a local Windows service (status|start|stop|restart as second argument).
param($Config, [array]$Arguments)
$Name = if ($Arguments[0]) { $Arguments[0] } else { $null }
$Action = if ($Arguments[1]) { $Arguments[1] } else { $null }
if (-not $Name) { Write-Host "[ERROR] Usage: svc <name> [status|start|stop|restart]" -ForegroundColor Red ; return }
if ($Action -eq 'start') { Start-Service $Name -ErrorAction SilentlyContinue }
elseif ($Action -eq 'stop') { Stop-Service $Name -Force -ErrorAction SilentlyContinue }
elseif ($Action -eq 'restart') { Restart-Service $Name -Force -ErrorAction SilentlyContinue }
Get-Service -Name $Name -ErrorAction SilentlyContinue | Select-Object Name, Status, DisplayName | Format-Table -AutoSize | Out-Host
