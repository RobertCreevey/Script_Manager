# Type: Action
# Description: Displays the default gateway, primary DNS server, and active network adapter info for the local machine.
param($Config, [array]$Arguments)
$C = Get-ToolkitColors
Write-Host "[gateway] Default gateway and adapter info..." -ForegroundColor Cyan
try {
    $Route = Get-NetRoute -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($Route) {
        Write-Host "  $($C.Sys)Default Gateway:$($C.Reset) $($C.Str)$($Route.NextHop)$($C.Reset)"
        $Adapter = Get-NetAdapter -InterfaceIndex $Route.InterfaceIndex -ErrorAction SilentlyContinue
        if ($Adapter) {
            Write-Host "  $($C.Sys)Adapter:$($C.Reset) $($C.Str)$($Adapter.Name)$($C.Reset) ($($Adapter.InterfaceDescription))"
            Write-Host "  $($C.Sys)Link Speed:$($C.Reset) $($C.Str)$($Adapter.LinkSpeed)$($C.Reset)  Status: $($Adapter.Status)"
        }
    }
    $Dns = Get-DnsClientServerAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object { $_.ServerAddresses } | Select-Object -First 1
    if ($Dns) { Write-Host "  $($C.Sys)DNS Server(s):$($C.Reset) $($C.Str)$($Dns.ServerAddresses -join ', ')$($C.Reset)" }
    $Ip = Get-NetIPAddress -AddressFamily IPv4 -InterfaceIndex $Route.InterfaceIndex -ErrorAction SilentlyContinue | Where-Object { $_.PrefixOrigin -eq 'Dhcp' -or $_.PrefixOrigin -eq 'Manual' } | Select-Object -First 1
    if ($Ip) { Write-Host "  $($C.Sys)IP Address:$($C.Reset) $($C.Str)$($Ip.IPAddress)$($C.Reset) / Prefix $($Ip.PrefixLength)" }
} catch {
    Write-Host "[FAIL] Could not read gateway info: $_" -ForegroundColor Red
}

