# Type: Action
# Description: Finds files by name pattern (supports wildcards) under a root directory, with optional size filtering.
param($Config, [array]$Arguments)
$C = if ($global:ToolColors) { $global:ToolColors } else { [PSCustomObject]@{}}
$ArgsOnly = @($Arguments | Where-Object { $_ -notin @("-Force", "-f") })
$Pattern = if ($ArgsOnly[0]) { $ArgsOnly[0] } else { "*" }
$Root = if ($ArgsOnly[1]) { $ArgsOnly[1] } else { $Config.Root }
$MinSize = if ($ArgsOnly[2] -and $ArgsOnly[2] -match '^\d+$') { [long]$ArgsOnly[2] * 1MB } else { 0 }
if (-not (Test-Path $Root)) { Write-Host "[ERROR] Root not found: $Root" -ForegroundColor Red ; return }
Write-Host "[find] '$Pattern' under $Root$(if($MinSize){" (>= $([int]($MinSize/1MB))MB)"})..." -ForegroundColor Cyan
try {
    $Files = Get-ChildItem -Path $Root -Recurse -Filter $Pattern -File -ErrorAction SilentlyContinue | Where-Object { $_.Length -ge $MinSize }
    $Total = ($Files | Measure-Object -Property Length -Sum).Sum
    $Files | Sort-Object Length -Descending | Select-Object -First 50 | ForEach-Object {
        Write-Host "  $($C.Str)$($_.FullName)$($C.Reset)  ($($C.Param)$([math]::Round($_.Length/1KB,1))KB$($C.Reset))"
    }
    Write-Host "[find] $($Files.Count) file(s), total $([math]::Round($Total/1MB,2)) MB" -ForegroundColor Yellow
} catch {
    Write-Host "[FAIL] Find failed: $_" -ForegroundColor Red
}
