# Type: Listener
# Description: Remote egress sweep listener that pings a well-known address via the active SSH profile (fast-fails if the target is offline).
param($Config, [array]$Arguments)

if (-not (Test-Connection -ComputerName $Config.IP -Count 1 -Quiet)) { Write-Host "[ABORT] Target offline." -ForegroundColor Yellow ; return }

$Auth = "-i `"$($Config.Key)`""
$Target = "$($Config.User)@$($Config.IP)"
Write-Host "[Netcheck Listener] Sweeping $Target ..." -ForegroundColor Cyan
$Result = & ssh -o ConnectTimeout=8 -o BatchMode=yes $Auth $Target "ping -c 1 8.8.8.8"
if ($LASTEXITCODE -eq 0) { Write-Host "[PASS] Remote egress to 8.8.8.8 reachable." -ForegroundColor Green } else { Write-Host "[FAIL] Remote egress unreachable." -ForegroundColor Red }
