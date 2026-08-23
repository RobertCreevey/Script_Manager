# Type: Action
# Description: Reports free disk space on the remote host's fixed drives.
param($Config, [array]$Arguments)
if (-not (Test-Connection -ComputerName $Config.IP -Count 1 -Quiet)) { Write-Host "[ABORT] Target offline." -ForegroundColor Yellow ; return }
$Auth = "-i `"$($Config.Key)`""
$Target = "$($Config.User)@$($Config.IP)"
$Cmd = "wmic logicaldisk where DriveType=3 get Caption,FreeSpace,Size"
& ssh -o ConnectTimeout=8 -o BatchMode=yes $Auth $Target $Cmd
