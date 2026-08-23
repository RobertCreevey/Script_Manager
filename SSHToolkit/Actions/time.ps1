# Type: Action
# Description: Resynchronizes the remote host system clock against its time source via w32tm.
param($Config, [array]$Arguments)

if (-not (Test-Connection -ComputerName $Config.IP -Count 1 -Quiet)) { Write-Host "[ABORT] Target offline." -ForegroundColor Yellow ; return }
$Auth = "-i `"$($Config.Key)`""
$Target = "$($Config.User)@$($Config.IP)"
Write-Host "[*] Resyncing clock on $Target ..." -ForegroundColor Yellow
$Result = & ssh -o ConnectTimeout=8 -o BatchMode=yes $Auth $Target "w32tm /resync /nowarn"
if ($LASTEXITCODE -eq 0) { Write-Host "[DONE] Clock resynced." -ForegroundColor Green ; Write-Host $Result } else { Write-Host "[FAIL] Resync failed (try: net time \\host /set)." -ForegroundColor Red }
