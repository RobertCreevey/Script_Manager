# Type: Action
# Description: Securely copies a local file to the remote host (default C:\Users\Public). No remote traces left by caller.
param($Config, [array]$Arguments)
$Local = if ($Arguments[0]) { $Arguments[0] } else { $null }
$Dest = if ($Arguments[1]) { $Arguments[1] } else { "C:\Users\Public\" }
if (-not $Local -or -not (Test-Path $Local)) { Write-Host "[ERROR] Local file not found: $Local" -ForegroundColor Red ; return }
if (-not (Test-Connection -ComputerName $Config.IP -Count 1 -Quiet)) { Write-Host "[ABORT] Target offline." -ForegroundColor Yellow ; return }
$Auth = "-i `"$($Config.Key)`""
$Target = "$($Config.User)@$($Config.IP)"
& scp -o ConnectTimeout=8 -o BatchMode=yes $Auth "$Local" "${Target}:$Dest"
if ($LASTEXITCODE -eq 0) { Write-Host "[OK] Pushed to ${Target}:$Dest" -ForegroundColor Green } else { Write-Host "[FAIL] Push failed." -ForegroundColor Red }
& "$global:SharedToolkitPath\Actions\log.ps1" -Config $Config -Arguments @("Pushed $Local to $Target")
