# Type: Action
# Description: Executes an arbitrary command on the remote host via SSH and streams the output back. Requires confirmation unless -Force.
param($Config, [array]$Arguments)
$ArgsOnly = @($Arguments | Where-Object { $_ -notin @("-Force", "-f") })
if (-not (Test-Connection -ComputerName $Config.IP -Count 1 -Quiet)) { Write-Host "[ABORT] Target offline." -ForegroundColor Yellow ; return }
$Cmd = if ($ArgsOnly) { $ArgsOnly -join " " } else { "echo hello" }
$Auth = "-i `"$($Config.Key)`""
$Target = "$($Config.User)@$($Config.IP)"
if (-not (Request-ToolkitConfirmation -Verb "run command" -Command $Cmd -Config $Config -Arguments $Arguments -Dangerous)) { return }
& ssh -o ConnectTimeout=8 -o BatchMode=yes $Auth $Target $Cmd

