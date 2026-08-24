# Type: Action
# Description: Locks the target workstation (Win+L equivalent).
param($Config, [array]$Arguments)
$C = if ($global:ToolColors) { $global:ToolColors } else { [PSCustomObject]@{}}
$ArgsOnly = @($Arguments | Where-Object { $_ -notin @("-Force", "-f", "-json", "-csv", "-raw", "-table", "-h", "-?") })
$Format = "table"
if ($Arguments -contains '-json') { $Format = 'json' } elseif ($Arguments -contains '-csv') { $Format = 'csv' } elseif ($Arguments -contains '-raw') { $Format = 'raw' }

if (-not (Assert-ToolkitAction -Verb "lock workstation" -Command "lock" -Config $Config -Arguments $Arguments)) { return }

$IP = $Config.IP
$User = $Config.User
$Key = $Config.Key

Write-Host "[lock] Locking target workstation..." -ForegroundColor Cyan
$SSHCmd = "ssh -i `$Key $User@$IP rundll32.exe user32.dll,LockWorkStation"
& powershell -NoProfile -Command $SSHCmd

Write-Host "[OK] Workstation locked" -ForegroundColor Green
[PSCustomObject]@{ Action='lock'; Status='Completed' } | Format-ToolOutput -Format $Format