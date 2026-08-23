# Type: Action
# Description: Securely copies a file from the remote host to a local path (default Downloads folder). Requires confirmation unless -Force.
param($Config, [array]$Arguments)
$ArgsOnly = @($Arguments | Where-Object { $_ -notin @("-Force", "-f") })
$Remote = if ($ArgsOnly[0]) { $ArgsOnly[0] } else { $null }
$Local = if ($ArgsOnly[1]) { $ArgsOnly[1] } else { Join-Path $env:USERPROFILE "Downloads" }
if (-not $Remote) { Write-Host "[ERROR] Provide remote path." -ForegroundColor Red ; return }
if (-not (Test-Connection -ComputerName $Config.IP -Count 1 -Quiet)) { Write-Host "[ABORT] Target offline." -ForegroundColor Yellow ; return }
$Auth = "-i `"$($Config.Key)`""
$Target = "$($Config.User)@$($Config.IP)"
if (-not (Assert-ToolkitAction -Verb "pull file '$Remote'" -Command "scp ${Target}:$Remote -> $Local" -Config $Config -Arguments $Arguments -Dangerous)) { return }
& scp -o ConnectTimeout=8 -o BatchMode=yes $Auth "${Target}:$Remote" "$Local"
if ($LASTEXITCODE -eq 0) { Write-Host "[OK] Pulled to $Local" -ForegroundColor Green } else { Write-Host "[FAIL] Pull failed." -ForegroundColor Red }
& "$global:SharedToolkitPath\Actions\log.ps1" -Config $Config -Arguments @("Pulled $Remote from $Target")
