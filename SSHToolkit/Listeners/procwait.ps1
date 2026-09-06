# Type: Listener
# Description: Waits for a remote process to exit, then triggers a chain.
param($Config, [array]$Arguments)
$C = Get-ToolkitColors
$ArgsOnly = @($Arguments | Where-Object { $_ -notin @("-Force", "-f", "-h", "-?") })
$ProcessName = if ($ArgsOnly[0]) { $ArgsOnly[0] } else { "notepad" }
$ChainName = if ($ArgsOnly[1]) { $ArgsOnly[1] } else { "" }
$Interval = if ($ArgsOnly[2]) { [int]$ArgsOnly[2] } else { 5 }

if (-not $ChainName) {
    Write-Host "$($C.Crit)[ERROR] Usage: procwait <process> <chain> [interval_secs]$($C.Reset)"
    return
}

Write-Host "[procwait] Watching for '$ProcessName' to exit, then running chain '$ChainName'..." -ForegroundColor Cyan

$IP = $Config.IP
$User = $Config.User
$Key = $Config.Key

while ($true) {
    $CheckCmd = "ssh -i `$Key $User@$IP tasklist /FI `"IMAGENAME eq $ProcessName`" /FO CSV | Select-String $ProcessName"
    $Result = & powershell -NoProfile -Command $CheckCmd
    if (-not $Result) {
        Write-Host "[procwait] Process '$ProcessName' exited. Triggering chain '$ChainName'..." -ForegroundColor Green
        Invoke-ToolkitContextAction -Action "chain" -ForwardedArgs @("run", $ChainName)
        break
    }
    Start-Sleep -Seconds $Interval
}
