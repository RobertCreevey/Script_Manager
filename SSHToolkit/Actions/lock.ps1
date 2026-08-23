# Type: Action
# Description: Locks the remote workstation session via rundll32 LockWorkStation.
param($Config, [array]$Arguments)

if (-not (Test-Connection -ComputerName $Config.IP -Count 1 -Quiet)) { Write-Host "[ABORT] Target offline." -ForegroundColor Yellow ; return }
$Auth = "-i `"$($Config.Key)`""
$Target = "$($Config.User)@$($Config.IP)"
& "$global:SharedToolkitPath\Actions\log.ps1" -Config $Config -Arguments @("Locking workstation $Target")
& ssh -o ConnectTimeout=8 -o BatchMode=yes $Auth $Target "rundll32.exe user32.dll,LockWorkStation"
if ($LASTEXITCODE -eq 0) { Write-Host "[DONE] Lock command sent." -ForegroundColor Green } else { Write-Host "[FAIL] Lock command failed." -ForegroundColor Red }
