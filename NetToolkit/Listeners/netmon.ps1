# Type: Listener
# Description: Continuously monitors a target for online/offline state changes and alerts (toast+beep) on transition, with optional chain on recovery.
param($Config, [array]$Arguments)
$C = if ($global:ToolColors) { $global:ToolColors } else { [PSCustomObject]@{} }
$Chain = if ($Arguments) { $Arguments -join " " } else { $null }
$Target = if ($Config) { $Config.IP } else { "127.0.0.1" }
Write-Host "[netmon] Monitoring $Target for state changes (Ctrl+C to stop)..." -ForegroundColor Cyan
$WasOnline = $null
try {
    while ($true) {
        $Online = Test-Connection -ComputerName $Target -Count 1 -Quiet -ErrorAction SilentlyContinue
        if ($null -ne $WasOnline -and $Online -ne $WasOnline) {
            if ($Online) {
                Write-Host "[netmon] $($C.Ok)$Target is BACK ONLINE$($C.Reset)" -ForegroundColor Green
                & "$global:SharedToolkitPath\Actions\toast.ps1" -Config $Config -Arguments @("Online", "$Target recovered")
                [Console]::Beep(880, 300)
                if ($Chain) { Invoke-Expression $Chain }
            } else {
                Write-Host "[netmon] $($C.Warn)$Target went OFFLINE$($C.Reset)" -ForegroundColor Yellow
                & "$global:SharedToolkitPath\Actions\toast.ps1" -Config $Config -Arguments @("Offline", "$Target unreachable")
            }
        }
        $WasOnline = $Online
        Start-Sleep -Seconds 5
    }
} finally { Write-Host "[netmon] Stopped." -ForegroundColor Yellow }
