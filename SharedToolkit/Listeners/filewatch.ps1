# Type: Listener
# Description: Watches a directory for new files matching pattern, triggers chain on creation.
param($Config, [array]$Arguments)
$C = Get-ToolkitColors
$ArgsOnly = @($Arguments | Where-Object { $_ -notin @("-Force", "-f", "-h", "-?") })
$Path = if ($ArgsOnly[0]) { $ArgsOnly[0] } else { "C:\_Scripts" }
$Filter = if ($ArgsOnly[1]) { $ArgsOnly[1] } else { "*.mp4" }
$ChainName = if ($ArgsOnly[2]) { $ArgsOnly[2] } else { "" }
$Interval = if ($ArgsOnly[3]) { [int]$ArgsOnly[3] } else { 3 }

if (-not $ChainName) {
    Write-Host "$($C.Warn)[ERROR] Usage: filewatch <path> <filter> <chain> [interval_secs]$($C.Reset)"
    return
}

if (-not (Test-Path $Path)) {
    Write-Host "$($C.Warn)[ERROR] Path not found: $Path$($C.Reset)"
    return
}

$KnownFiles = @(Get-ChildItem $Path -Filter $Filter -File | Select-Object -ExpandProperty FullName)

Write-Host "[filewatch] Watching $Path for $Filter" -ForegroundColor Cyan
Write-Host "[filewatch] Will trigger chain: $ChainName" -ForegroundColor Cyan

while ($true) {
    $CurrentFiles = @(Get-ChildItem $Path -Filter $Filter -File | Select-Object -ExpandProperty FullName)
    $NewFiles = $CurrentFiles | Where-Object { $_ -notin $KnownFiles }
    foreach ($File in $NewFiles) {
        Write-Host "[filewatch] New file detected: $File" -ForegroundColor Green
        Write-Host "[filewatch] Triggering chain: $ChainName" -ForegroundColor Cyan
        Invoke-UniversalToolkitRouter -Action "chain" -ForwardedArgs @("run", $ChainName)
    }
    $KnownFiles = $CurrentFiles
    Start-Sleep -Seconds $Interval
}
