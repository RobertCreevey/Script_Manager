# Type: Action
# Description: Looks up the hardware vendor for a MAC address (first arg) using the IEEE OUI database. Falls back to profile MAC if no arg given.
param($Config, [array]$Arguments)
$Arguments = @($Arguments)
$C = if ($global:ToolColors) { $global:ToolColors } else { [PSCustomObject]@{}}
$MAC = if ($Arguments[0]) { $Arguments[0] } elseif ($Config.MAC) { $Config.MAC } else { $null }
if (-not $MAC) { Write-Host "[ERROR] Provide a MAC address or set profile MAC." -ForegroundColor Red ; return }
$Prefix = ($MAC -replace '[:-]').Substring(0,6).ToUpper()
Write-Host "[macvendor] Looking up $Prefix..." -ForegroundColor Cyan
try {
    $Html = Invoke-WebRequest -Uri "https://api.macvendors.com/$Prefix" -TimeoutSec 8 -UseBasicParsing -ErrorAction Stop
    Write-Host "  $($C.Sys)$MAC$($C.Reset) → $($C.Ok)$($Html.Content)$($C.Reset)" -ForegroundColor Green
} catch {
    Write-Host "[FAIL] Lookup failed (rate-limited or offline): $_" -ForegroundColor Red
}
