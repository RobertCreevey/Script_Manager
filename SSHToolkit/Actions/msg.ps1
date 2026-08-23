# Type: Action
# Description: Sends a popup message to the remote interactive session using msg.exe. Requires confirmation unless -Force.
param($Config, [array]$Arguments)
$ArgsOnly = @($Arguments | Where-Object { $_ -notin @("-Force", "-f") })
$Message = if ($ArgsOnly) { $ArgsOnly -join " " } else { "Hello from SSHToolkit" }
if (-not (Test-Connection -ComputerName $Config.IP -Count 1 -Quiet)) { Write-Host "[ABORT] Target offline." -ForegroundColor Yellow ; return }
$Auth = "-i `"$($Config.Key)`""
$Target = "$($Config.User)@$($Config.IP)"
if (-not (Assert-ToolkitAction -Verb "send message" -Command "msg * $Message" -Config $Config -Arguments $Arguments)) { return }
& ssh -o ConnectTimeout=8 -o BatchMode=yes $Auth $Target "msg * $Message"
Write-Host "[OK] Message sent to $Target" -ForegroundColor Green
