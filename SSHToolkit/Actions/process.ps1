# Type: Action
# Description: Lists remote processes (filtered by name fragment) or kills a process when second arg is 'kill'. Kill requires confirmation unless -Force.
param($Config, [array]$Arguments)
$ArgsOnly = @($Arguments | Where-Object { $_ -notin @("-Force", "-f") })
$Name = if ($ArgsOnly[0]) { $ArgsOnly[0] } else { $null }
$Action = if ($ArgsOnly[1]) { $ArgsOnly[1] } else { $null }
if (-not (Test-Connection -ComputerName $Config.IP -Count 1 -Quiet)) { Write-Host "[ABORT] Target offline." -ForegroundColor Yellow ; return }
$Auth = "-i `"$($Config.Key)`""
$Target = "$($Config.User)@$($Config.IP)"
if ($Action -eq "kill") {
    if (-not $Name) { Write-Host "[ERROR] Usage: process <name> kill" -ForegroundColor Red ; return }
    if (-not (Assert-ToolkitAction -Verb "kill process '$Name'" -Command "taskkill /IM $Name /F" -Config $Config -Arguments $Arguments -Dangerous)) { return }
    $Cmd = "taskkill /IM $Name /F"
} elseif ($Name) {
    $Cmd = "tasklist /FI `"IMAGENAME eq $Name`""
} else {
    $Cmd = "tasklist"
}
& ssh -o ConnectTimeout=8 -o BatchMode=yes $Auth $Target $Cmd
