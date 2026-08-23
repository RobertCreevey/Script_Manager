# Type: Listener
# Description: Polls the target and fires a toast/beep alert (plus optional chain) as soon as it comes online.
param($Config, [array]$Arguments)
$Chain = if ($Arguments) { $Arguments -join " " } else { $null }
$C = if ($global:ToolColors) { $global:ToolColors } else { [PSCustomObject]@{} }
Write-Host "[onlinemon] Watching $($C.Str)$($Config.IP)$($C.Reset) for online event [Ctrl+C to stop]" -ForegroundColor Cyan
try {
    while ($true) {
        if (Test-Connection -ComputerName $Config.IP -Count 1 -Quiet) {
            Write-Host "[onlinemon] $($Config.IP) is ONLINE!" -ForegroundColor Green
            & "$global:SharedToolkitPath\Actions\toast.ps1" -Config $Config -Arguments @("Online", "$($Config.IP) is back")
            [Console]::Beep(880, 300)
            if ($Chain) { Invoke-Expression $Chain }
            break
        }
        Start-Sleep -Seconds 5
    }
} finally { Write-Host "[onlinemon] Stopped." -ForegroundColor Yellow }
