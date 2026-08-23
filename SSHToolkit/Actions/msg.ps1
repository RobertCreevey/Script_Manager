# Type: Action
# Description: Sends a popup message to the remote interactive session using msg.exe.
param($Config, [array]$Arguments)
$Message = if ($Arguments) { $Arguments -join " " } else { "Hello from SSHToolkit" }
if (-not (Test-Connection -ComputerName $Config.IP -Count 1 -Quiet)) { Write-Host "[ABORT] Target offline." -ForegroundColor Yellow ; return }
$Auth = "-i `"$($Config.Key)`""
$Target = "$($Config.User)@$($Config.IP)"
& ssh -o ConnectTimeout=8 -o BatchMode=yes $Auth $Target "msg * $Message"
Write-Host "[OK] Message sent to $Target" -ForegroundColor Green
