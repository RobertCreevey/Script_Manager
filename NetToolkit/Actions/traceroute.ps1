# Type: Action
# Description: Runs a traceroute to the target (default profile IP) showing each hop latency.
param($Config, [array]$Arguments)
$C = if ($global:ToolColors) { $global:ToolColors } else { [PSCustomObject]@{}}
$ArgsOnly = @($Arguments | Where-Object { $_ -notin @("-Force", "-f") })
$Target = if ($ArgsOnly[0]) { $ArgsOnly[0] } else { $Config.IP }
if (-not $Target) { Write-Host "[ERROR] Provide a target IP or set profile IP." -ForegroundColor Red ; return }
$MaxHops = if ($ArgsOnly[1] -and $ArgsOnly[1] -match '^\d+$') { [int]$ArgsOnly[1] } else { 30 }
Write-Host "[trace] $Target (max $MaxHops hops)..." -ForegroundColor Cyan
$Hop = 0
while ($Hop -lt $MaxHops) {
    $Hop++
    try {
        $Ping = Test-Connection -ComputerName $Target -Count 1 -ErrorAction Stop
        $Reply = $Ping | Select-Object -First 1
        Write-Host "  $($C.Param)$($Hop.ToString().PadLeft(2))$($C.Reset) $($C.Str)$($Reply.IPV4Address.IPAddressToString)$($C.Reset) ($([math]::Round($Reply.ResponseTime,1))ms)"
        if ($Reply.IPV4Address.IPAddressToString -eq $Target) { Write-Host "[trace] reached target." -ForegroundColor Green; break }
    } catch {
        Write-Host "  $($C.Param)$($Hop.ToString().PadLeft(2))$($C.Reset) $($C.Warn)* timeout" -ForegroundColor Yellow
    }
}
