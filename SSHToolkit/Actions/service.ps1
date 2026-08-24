# Type: Action
# Description: Queries or controls a remote Windows service (status|start|stop|restart as second arg). Mutating actions require confirmation unless -Force.
param($Config, [array]$Arguments)
$ArgsOnly = @($Arguments | Where-Object { $_ -notin @("-Force", "-f") })
$Name = if ($ArgsOnly[0]) { $ArgsOnly[0] } else { $null }
$Action = if ($ArgsOnly[1]) { $ArgsOnly[1] } else { "status" }
if (-not $Name) { Write-Host "[ERROR] Usage: service <name> [status|start|stop|restart]" -ForegroundColor Red ; return }
if (-not (Test-Connection -ComputerName $Config.IP -Count 1 -Quiet)) { Write-Host "[ABORT] Target offline." -ForegroundColor Yellow ; return }
$Auth = "-i `"$($Config.Key)`""
$Target = "$($Config.User)@$($Config.IP)"
if ($Action -ne "status") {
    if (-not (Request-ToolkitConfirmation -Verb "$Action service '$Name'" -Command "$Action $Name" -Config $Config -Arguments $Arguments -Dangerous)) { return }
}
$Cmd = "powershell -NoProfile -Command `"`$s=Get-Service -Name '$Name' -ErrorAction SilentlyContinue; if(-not `$s){'Service not found'}else{ if('$Action'-eq'start'){`$s.Start()} if('$Action'-eq'stop'){`$s.Stop()} if('$Action'-eq'restart'){`$s.Restart()} Start-Sleep 1; (Get-Service -Name '$Name').Status }`""
& ssh -o ConnectTimeout=8 -o BatchMode=yes $Auth $Target $Cmd

