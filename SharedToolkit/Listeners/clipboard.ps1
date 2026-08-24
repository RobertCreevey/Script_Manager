# Type: Listener
# Description: Monitors clipboard for IP addresses or file paths, triggers chain on match.
param($Config, [array]$Arguments)
$C = if ($global:ToolColors) { $global:ToolColors } else { [PSCustomObject]@{}}
$ArgsOnly = @($Arguments | Where-Object { $_ -notin @("-Force", "-f", "-h", "-?") })
$ChainName = if ($ArgsOnly[0]) { $ArgsOnly[0] } else { "" }
$Pattern = if ($ArgsOnly[1]) { $ArgsOnly[1] } else { '(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})|([A-Za-z]:\\\\[^<>:"/\\|?*]+)' }
$Interval = if ($ArgsOnly[2]) { [int]$ArgsOnly[2] } else { 2 }

if (-not $ChainName) {
    Write-Host "$($C.Warn)[ERROR] Usage: clipboard <chain> [regex_pattern] [interval_secs]$($C.Reset)"
    return
}

Add-Type -AssemblyName System.Windows.Forms
$LastContent = ""

Write-Host "[clipboard] Monitoring clipboard for pattern: $Pattern" -ForegroundColor Cyan
Write-Host "[clipboard] Will trigger chain: $ChainName" -ForegroundColor Cyan

while ($true) {
    try {
        $Content = Get-Clipboard -ErrorAction SilentlyContinue
        if ($Content -and $Content -ne $LastContent) {
            if ($Content -match $Pattern) {
                Write-Host "[clipboard] Match detected: $($Matches[0])" -ForegroundColor Green
                Write-Host "[clipboard] Triggering chain: $ChainName" -ForegroundColor Cyan
                Invoke-UniversalToolkitRouter -Action "chain" -ForwardedArgs @("run", $ChainName)
                $LastContent = $Content
            }
        }
    } catch {}
    Start-Sleep -Seconds $Interval
}