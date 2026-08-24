# Type: Action
# Description: Flushes the local DNS cache and optionally resolves a hostname against a specific DNS server.
param($Config, [array]$Arguments)
$C = Get-ToolkitColors
$ArgsOnly = @($Arguments | Where-Object { $_ -notin @("-Force", "-f") })
if ($ArgsOnly -contains "-flush") {
    Clear-DnsClientCache -ErrorAction SilentlyContinue
    Write-Host "[OK] DNS client cache flushed." -ForegroundColor Green
}
if ($ArgsOnly[0] -and $ArgsOnly[0] -ne "-flush") {
    $Name = $ArgsOnly[0]
    $Server = if ($ArgsOnly[1]) { $ArgsOnly[1] } else { $null }
    Write-Host "[dns] Resolving $Name$(if($Server){" via $Server"})..." -ForegroundColor Cyan
    try {
        $Param = @{Name = $Name; ErrorAction = 'Stop'}
        if ($Server) { $Param['Server'] = $Server }
        $Results = Resolve-DnsName @Param
        foreach ($R in $Results) {
            Write-Host "  $($C.Str)$($R.Type)$($C.Reset) : $($C.Ok)$($R.IPAddress)$($C.Reset)  (TTL $($R.TTL))"
        }
    } catch {
        Write-Host "[FAIL] DNS resolution failed: $_" -ForegroundColor Red
    }
}
if ($ArgsOnly.Count -eq 0) {
    Clear-DnsClientCache -ErrorAction SilentlyContinue
    Write-Host "[OK] DNS client cache flushed." -ForegroundColor Green
}

