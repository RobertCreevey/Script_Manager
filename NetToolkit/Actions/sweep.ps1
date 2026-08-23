# Type: Action
# Description: Pings a target or sweeps a subnet (/24 from first three octets) and reports which hosts are online.
param($Config, [array]$Arguments)
$C = if ($global:ToolColors) { $global:ToolColors } else { [PSCustomObject]@{}}
$ArgsOnly = @($Arguments | Where-Object { $_ -notin @("-Force", "-f") })
$Target = if ($ArgsOnly[0]) { $ArgsOnly[0] } else { $Config.IP }
if (-not $Target) { Write-Host "[ERROR] Provide an IP or subnet (e.g. 192.168.1) or set profile IP." -ForegroundColor Red ; return }
$Count = if ($ArgsOnly[1] -and $ArgsOnly[1] -match '^\d+$') { [int]$ArgsOnly[1] } else { 1 }
if ($Target -match '^\d{1,3}(\.\d{1,3}){2}$') {
    Write-Host "[sweep] Scanning $Target.0/24 ..." -ForegroundColor Cyan
    $Found = 0
    1..254 | ForEach-Object {
        $IP = "$Target.$_"
        if (Test-Connection -ComputerName $IP -Count $Count -Quiet -ErrorAction SilentlyContinue) {
            Write-Host "  $($C.Ok)ONLINE$($C.Reset) : $($C.Str)$IP$($C.Reset)" -ForegroundColor Green
            $Found++
        }
    }
    Write-Host "[sweep] $Found host(s) online." -ForegroundColor Yellow
} else {
    Write-Host "[ping] $Target (count=$Count)..." -ForegroundColor Cyan
    $R = Test-Connection -ComputerName $Target -Count $Count -ErrorAction SilentlyContinue
    if ($R) { Write-Host "  $($C.Ok)REACHABLE$($C.Reset) : $($C.Str)$Target$($C.Reset) (avg $([math]::Round(($R | Measure-Object ResponseTime -Average).Average,1))ms)" -ForegroundColor Green }
    else { Write-Host "  $($C.Warn)UNREACHABLE$($C.Reset) : $Target" -ForegroundColor Red }
}
