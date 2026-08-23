# Type: Action
# Description: Lists the most recently modified files under a root, with age and size.
param($Config, [array]$Arguments)
$C = if ($global:ToolColors) { $global:ToolColors } else { [PSCustomObject]@{}}
$ArgsOnly = @($Arguments | Where-Object { $_ -notin @("-Force", "-f") })
$Root = if ($ArgsOnly[0]) { $ArgsOnly[0] } else { $Config.Root }
$Top = if ($ArgsOnly[1] -and $ArgsOnly[1] -match '^\d+$') { [int]$ArgsOnly[1] } else { 20 }
if (-not (Test-Path $Root)) { Write-Host "[ERROR] Root not found: $Root" -ForegroundColor Red ; return }
Write-Host "[recent] Last $Top modified files under $Root..." -ForegroundColor Cyan
try {
    Get-ChildItem -Path $Root -Recurse -File -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending | Select-Object -First $Top | ForEach-Object {
            $Age = [math]::Round(((Get-Date) - $_.LastWriteTime).TotalHours, 1)
            Write-Host "  $($C.Str)$($_.LastWriteTime.ToString('yyyy-MM-dd HH:mm'))$($C.Reset)  $($C.Param)$([math]::Round($_.Length/1KB,1))KB$($C.Reset)  $($C.Info)${Age}h$($C.Reset)  $($_.FullName)"
        }
} catch {
    Write-Host "[FAIL] Recent-files failed: $_" -ForegroundColor Red
}
