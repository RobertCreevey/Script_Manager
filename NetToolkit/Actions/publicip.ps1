# Type: Action
# Description: Fetches and displays the public (external) IPv4 address using an external service.
param($Config, [array]$Arguments)
$C = Get-ToolkitColors
Write-Host "[publicip] Fetching public IP..." -ForegroundColor Cyan
try {
    $Ip = (Invoke-RestMethod -Uri 'https://api.ipify.org?format=json' -TimeoutSec 8 -ErrorAction Stop).ip
    Write-Host "  $($C.Sys)Public IP:$($C.Reset) $($C.Ok)$Ip$($C.Reset)" -ForegroundColor Green
} catch {
    try {
        $Ip = (Invoke-WebRequest -Uri 'https://ifconfig.me/ip' -TimeoutSec 8 -UseBasicParsing -ErrorAction Stop).Content.Trim()
        Write-Host "  $($C.Sys)Public IP:$($C.Reset) $($C.Ok)$Ip$($C.Reset)" -ForegroundColor Green
    } catch {
        Write-Host "[FAIL] Could not fetch public IP: $_" -ForegroundColor Red
    }
}

