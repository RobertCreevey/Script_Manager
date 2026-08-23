# Type: Action
# Description: Securely copies a file from the remote host to a local path (default Downloads folder).
param($Config, [array]$Arguments)
$Remote = if ($Arguments[0]) { $Arguments[0] } else { $null }
$Local = if ($Arguments[1]) { $Arguments[1] } else { Join-Path $env:USERPROFILE "Downloads" }
if (-not $Remote) { Write-Host "[ERROR] Provide remote path." -ForegroundColor Red ; return }
if (-not (Test-Connection -ComputerName $Config.IP -Count 1 -Quiet)) { Write-Host "[ABORT] Target offline." -ForegroundColor Yellow ; return }
$Auth = "-i `"$($Config.Key)`""
$Target = "$($Config.User)@$($Config.IP)"
& scp -o ConnectTimeout=8 -o BatchMode=yes $Auth "${Target}:$Remote" "$Local"
if ($LASTEXITCODE -eq 0) { Write-Host "[OK] Pulled to $Local" -ForegroundColor Green } else { Write-Host "[FAIL] Pull failed." -ForegroundColor Red }
& "$global:SharedToolkitPath\Actions\log.ps1" -Config $Config -Arguments @("Pulled $Remote from $Target")
