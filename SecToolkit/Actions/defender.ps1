# Type: Action
# Description: Shows Windows Defender status: real-time protection, antispyware, network protection, and signature age.
param($Config, [array]$Arguments)
$C = if ($global:ToolColors) { $global:ToolColors } else { [PSCustomObject]@{}}
Write-Host "[defender] Windows Defender status..." -ForegroundColor Cyan
try {
    $Status = Get-MpComputerStatus -ErrorAction SilentlyContinue
    if (-not $Status) { Write-Host "  (Defender not available or disabled)" -ForegroundColor Yellow; return }
    function Status-Text($On) { if ($On) { "$($C.Ok)ON" } else { "$($C.Warn)OFF" } }
    Write-Host "  $($C.Sys)Real-time Protection:$($C.Reset) $(Status-Text $Status.RealTimeProtectionEnabled)"
    Write-Host "  $($C.Sys)Antispyware:$($C.Reset) $(Status-Text $Status.AntispywareEnabled)"
    Write-Host "  $($C.Sys)Network Protection:$($C.Reset) $(Status-Text $Status.NetworkProtectionEnabled)"
    Write-Host "  $($C.Sys)Behavior Monitor:$($C.Reset) $(Status-Text $Status.BehaviorMonitorEnabled)"
    Write-Host "  $($C.Sys)Last Quick Scan:$($C.Reset) $($C.Str)$($Status.QuickScanEndTime)$($C.Reset)"
    Write-Host "  $($C.Sys)Signatures:$($C.Reset) $($C.Str)$($Status.AntivirusSignatureLastUpdated)$($C.Reset)"
} catch {
    Write-Host "[FAIL] Could not read Defender status: $_" -ForegroundColor Red
}
