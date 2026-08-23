# Type: Action
# Description: Executes an arbitrary command on the remote host via SSH and streams the output back.
param($Config, [array]$Arguments)
if (-not (Test-Connection -ComputerName $Config.IP -Count 1 -Quiet)) { Write-Host "[ABORT] Target offline." -ForegroundColor Yellow ; return }
$Cmd = if ($Arguments) { $Arguments -join " " } else { "echo hello" }
$Auth = "-i `"$($Config.Key)`""
$Target = "$($Config.User)@$($Config.IP)"
& ssh -o ConnectTimeout=8 -o BatchMode=yes $Auth $Target $Cmd
