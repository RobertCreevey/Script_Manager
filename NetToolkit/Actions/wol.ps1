# Type: Action
# Description: Sends a Wake-on-LAN magic packet to the target MAC address (uses profile MAC or first arg; broadcast optional).
param($Config, [array]$Arguments)
$C = if ($global:ToolColors) { $global:ToolColors } else { [PSCustomObject]@{} }
$ArgsOnly = @($Arguments | Where-Object { $_ -notin @("-Force", "-f") })
$MAC = if ($ArgsOnly[0]) { $ArgsOnly[0] } elseif ($Config.MAC) { $Config.MAC } else { $null }
$Broadcast = if ($ArgsOnly[1]) { $ArgsOnly[1] } elseif ($Config.Broadcast) { $Config.Broadcast } else { "255.255.255.255" }
if (-not $MAC) { Write-Host "[ERROR] Provide a MAC address (aa:bb:cc:dd:ee:ff) or set profile MAC." -ForegroundColor Red ; return }
if (-not ($MAC -match '^([0-9A-Fa-f]{2}[:-]){5}[0-9A-Fa-f]{2}$')) { Write-Host "[ERROR] Invalid MAC format: $MAC" -ForegroundColor Red ; return }
if (-not (Assert-ToolkitAction -Verb "Wake-on-LAN" -Command "magic packet to $MAC via $Broadcast" -Config $Config -Arguments $Arguments)) { return }
$MacBytes = ($MAC -split '[:-]' | ForEach-Object { [byte]('0x' + $_) })
$Packet = [byte[]]@(0xFF) * 6 + ($MacBytes * 16)
try {
    $Udp = New-Object System.Net.Sockets.UdpClient
    $Udp.Connect($Broadcast, 9)
    $Udp.Send($Packet, $Packet.Count) | Out-Null
    $Udp.Close()
    Write-Host "[OK] Magic packet sent to $($C.Str)$MAC$($C.Reset) via $Broadcast" -ForegroundColor Green
} catch {
    Write-Host "[FAIL] WOL send failed: $_" -ForegroundColor Red
}
& "$global:SharedToolkitPath\Actions\log.ps1" -Config $Config -Args @("WOL sent to $MAC")
