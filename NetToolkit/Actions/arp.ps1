# Type: Action
# Description: Displays the local ARP table mapping IP addresses to MAC addresses, optionally filtered by subnet.
param($Config, [array]$Arguments)
$Arguments = @($Arguments)
$C = if ($global:ToolColors) { $global:ToolColors } else { [PSCustomObject]@{}}
$Filter = if ($Arguments[0]) { $Arguments[0] } else { $null }
Write-Host "[arp] Local ARP table$(if($Filter){" (filter: $Filter)"})..." -ForegroundColor Cyan
try {
    $Arp = Get-NetNeighbor -ErrorAction SilentlyContinue | Where-Object { $_.State -ne 'Unreachable' -and (!$Filter -or $_.IPAddress -like "$Filter*") }
    if (-not $Arp) { Write-Host "  (no entries)" -ForegroundColor Gray; return }
    $Arp | Sort-Object IPAddress | ForEach-Object {
        Write-Host "  $($C.Str)$($_.IPAddress.PadLeft(15))$($C.Reset)  $($C.Ok)$($_.LinkLayerAddress)$($C.Reset)  [$($_.State)]"
    }
} catch {
    Write-Host "[FAIL] Could not read ARP table: $_" -ForegroundColor Red
}
