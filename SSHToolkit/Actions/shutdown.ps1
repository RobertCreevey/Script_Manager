# Type: Action
# Description: Remotely shuts down, restarts, or sleeps the target (action as first arg: shutdown|restart|sleep).
param($Config, [array]$Arguments)
$Action = if ($Arguments[0]) { $Arguments[0] } else { "shutdown" }
if (-not (Test-Connection -ComputerName $Config.IP -Count 1 -Quiet)) { Write-Host "[ABORT] Target offline." -ForegroundColor Yellow ; return }
$Auth = "-i `"$($Config.Key)`""
$Target = "$($Config.User)@$($Config.IP)"
if ($Action -eq "restart") { $Cmd = "shutdown /r /t 0" }
elseif ($Action -eq "sleep") { $Cmd = "rundll32.exe powrprof.dll,SetSuspendState 0,1,0" }
else { $Cmd = "shutdown /s /t 0" }
& ssh -o ConnectTimeout=8 -o BatchMode=yes $Auth $Target $Cmd
Write-Host "[OK] Sent '$Action' to $Target" -ForegroundColor Green
& "$global:SharedToolkitPath\Actions\log.ps1" -Config $Config -Arguments @("Sent $Action to $Target")
