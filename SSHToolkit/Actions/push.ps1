# Type: Action
# Description: Securely copies a local file to the remote host (default C:\Users\Public). Requires confirmation unless -Force.
param($Config, [array]$Arguments)
$ArgsOnly = @($Arguments | Where-Object { $_ -notin @("-Force", "-f") })
$Local = if ($ArgsOnly[0]) { $ArgsOnly[0] } else { $null }
$Dest = if ($ArgsOnly[1]) { $ArgsOnly[1] } else { "C:\Users\Public\" }
if (-not $Local -or -not (Test-Path $Local)) { Write-Host "[ERROR] Local file not found: $Local" -ForegroundColor Red ; return }
if (-not (Test-Connection -ComputerName $Config.IP -Count 1 -Quiet)) { Write-Host "[ABORT] Target offline." -ForegroundColor Yellow ; return }
$Auth = "-i `"$($Config.Key)`""
$Target = "$($Config.User)@$($Config.IP)"
if (-not (Request-ToolkitConfirmation -Verb "push file '$Local'" -Command "scp $Local -> ${Target}:$Dest" -Config $Config -Arguments $Arguments -Dangerous)) { return }
& scp -o ConnectTimeout=8 -o BatchMode=yes $Auth "$Local" "${Target}:$Dest"
if ($LASTEXITCODE -eq 0) { Write-Host "[OK] Pushed to ${Target}:$Dest" -ForegroundColor Green } else { Write-Host "[FAIL] Push failed." -ForegroundColor Red }
& "$global:SharedToolkitPath\Actions\log.ps1" -Config $Config -Arguments @("Pushed $Local to $Target")

