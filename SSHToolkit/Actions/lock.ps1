# Type: Action
# Description: Locks the remote workstation session via rundll32 LockWorkStation. Requires confirmation unless -Force.
param($Config, [array]$Arguments)
$ArgsOnly = @($Arguments | Where-Object { $_ -notin @("-Force", "-f") })
if (-not (Test-Connection -ComputerName $Config.IP -Count 1 -Quiet)) { Write-Host "[ABORT] Target offline." -ForegroundColor Yellow ; return }
$Auth = "-i `"$($Config.Key)`""
$Target = "$($Config.User)@$($Config.IP)"
if (-not (Assert-ToolkitAction -Verb "lock workstation" -Command "rundll32 user32.dll,LockWorkStation" -Config $Config -Arguments $Arguments -Dangerous)) { return }
& ssh -o ConnectTimeout=8 -o BatchMode=yes $Auth $Target "rundll32.exe user32.dll,LockWorkStation"
if ($LASTEXITCODE -eq 0) { Write-Host "[DONE] Lock command sent." -ForegroundColor Green } else { Write-Host "[FAIL] Lock command failed." -ForegroundColor Red }
