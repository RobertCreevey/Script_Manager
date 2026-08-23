# Type: Action
# Description: Lists remote processes (filtered by name fragment) or kills a process when second arg is 'kill'.
param($Config, [array]$Arguments)
$Name = if ($Arguments[0]) { $Arguments[0] } else { $null }
$Action = if ($Arguments[1]) { $Arguments[1] } else { $null }
if (-not (Test-Connection -ComputerName $Config.IP -Count 1 -Quiet)) { Write-Host "[ABORT] Target offline." -ForegroundColor Yellow ; return }
$Auth = "-i `"$($Config.Key)`""
$Target = "$($Config.User)@$($Config.IP)"
if ($Action -eq "kill") {
    $Cmd = "taskkill /IM $Name /F"
} elseif ($Name) {
    $Cmd = "tasklist /FI `"IMAGENAME eq $Name`""
} else {
    $Cmd = "tasklist"
}
& ssh -o ConnectTimeout=8 -o BatchMode=yes $Auth $Target $Cmd
