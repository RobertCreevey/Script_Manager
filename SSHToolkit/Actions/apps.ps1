# Type: Action
# Description: Lists applications with visible windows running on the remote host via the active SSH profile.
param($Config, [array]$Arguments)

if (-not (Test-Connection -ComputerName $Config.IP -Count 1 -Quiet)) { Write-Host "[ABORT] Target offline." -ForegroundColor Yellow ; return }
$Auth = "-i `"$($Config.Key)`""
$Target = "$($Config.User)@$($Config.IP)"
Write-Host "[*] Querying open applications on $Target ..." -ForegroundColor Yellow
$Result = & ssh -o ConnectTimeout=8 -o BatchMode=yes $Auth $Target "powershell -NoProfile -Command \"Get-Process | Where-Object { `$_.MainWindowTitle } | Select-Object Name,MainWindowTitle,Id | Format-Table -AutoSize | Out-String\""
if ($LASTEXITCODE -eq 0) { Write-Host $Result } else { Write-Host "[FAIL] Remote query failed." -ForegroundColor Red }
