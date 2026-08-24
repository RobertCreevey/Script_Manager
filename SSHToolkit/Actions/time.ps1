# Type: Action
# Description: Resynchronizes the target's system clock with its time source (w32tm).
param($Config, [array]$Arguments)
$C = if ($global:ToolColors) { $global:ToolColors } else { [PSCustomObject]@{}}
$ArgsOnly = @($Arguments | Where-Object { $_ -notin @("-Force", "-f", "-json", "-csv", "-raw", "-table", "-h", "-?") })
$Format = "table"
if ($Arguments -contains '-json') { $Format = 'json' } elseif ($Arguments -contains '-csv') { $Format = 'csv' } elseif ($Arguments -contains '-raw') { $Format = 'raw' }
$Force = $Arguments -contains '-f' -or $Arguments -contains '-Force'

if (-not $Force -and -not (Assert-ToolkitAction -Verb "resync time" -Command "w32tm /resync" -Config $Config -Arguments $Arguments)) { return }

$IP = $Config.IP
$User = $Config.User
$Key = $Config.Key

Write-Host "[time] Resynchronizing target clock..." -ForegroundColor Cyan
$SSHCmd = "ssh -i `$Key $User@$IP w32tm /resync /nowarn"
& powershell -NoProfile -Command $SSHCmd

Write-Host "[OK] Time resync triggered" -ForegroundColor Green
[PSCustomObject]@{ Action='time'; Status='Completed' } | Format-ToolOutput -Format $Format