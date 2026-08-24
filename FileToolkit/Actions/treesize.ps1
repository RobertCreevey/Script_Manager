# Type: Action
# Description: Shows directory tree sizes under a root, sorted by total size descending (like du/ ncdu).
param($Config, [array]$Arguments)
$C = Get-ToolkitColors
$ArgsOnly = @($Arguments | Where-Object { $_ -notin @("-Force", "-f") })
$Root = if ($ArgsOnly[0]) { $ArgsOnly[0] } else { $Config.Root }
$Depth = if ($ArgsOnly[1] -and $ArgsOnly[1] -match '^\d+$') { [int]$ArgsOnly[1] } else { 2 }
if (-not (Test-Path $Root)) { Write-Host "[ERROR] Root not found: $Root" -ForegroundColor Red ; return }
Write-Host "[treesize] Computing sizes under $Root (depth $Depth)..." -ForegroundColor Cyan
try {
    $Dirs = Get-ChildItem -Path $Root -Directory -Recurse -Depth $Depth -ErrorAction SilentlyContinue
    $Results = foreach ($D in $Dirs) {
        $Size = (Get-ChildItem -Path $D.FullName -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
        [PSCustomObject]@{Path=$D.FullName; Size=$Size}
    }
    $Results | Sort-Object Size -Descending | ForEach-Object {
        Write-Host "  $($C.Param)$([math]::Round($_.Size/1MB,2)).ToString('0.00').PadLeft(8) MB$($C.Reset)  $($C.Str)$($_.Path)$($C.Reset)"
    }
} catch {
    Write-Host "[FAIL] Treesize failed: $_" -ForegroundColor Red
}

