# Type: Action
# Description: Finds duplicate files under a root by computing SHA256 hashes, grouping identical files to reclaim space. Requires confirmation unless -Force.
param($Config, [array]$Arguments)
$C = if ($global:ToolColors) { $global:ToolColors } else { [PSCustomObject]@{}}
$ArgsOnly = @($Arguments | Where-Object { $_ -notin @("-Force", "-f") })
$Root = if ($ArgsOnly[0]) { $ArgsOnly[0] } else { $Config.Root }
if (-not (Test-Path $Root)) { Write-Host "[ERROR] Root not found: $Root" -ForegroundColor Red ; return }
Write-Host "[dedupe] Hashing files under $Root..." -ForegroundColor Cyan
try {
    $Files = Get-ChildItem -Path $Root -Recurse -File -ErrorAction SilentlyContinue
    $Hashes = @{}
    $Count = 0
    foreach ($F in $Files) {
        $Hash = (Get-FileHash -Path $F.FullName -Algorithm SHA256 -ErrorAction SilentlyContinue).Hash
        if ($Hash) {
            if (-not $Hashes[$Hash]) { $Hashes[$Hash] = @() }
            $Hashes[$Hash] += $F
        }
        $Count++
    }
    $DupGroups = $Hashes.GetEnumerator() | Where-Object { $_.Value.Count -gt 1 }
    $Waste = 0
    foreach ($Group in $DupGroups) {
        Write-Host "  $($C.Warn)DUPLICATE ($($Group.Value.Count) copies):$($C.Reset) $($Group.Value[0].Length) bytes"
        foreach ($Dup in $Group.Value) { Write-Host "    $($C.Str)$($Dup.FullName)$($C.Reset)" }
        $Waste += $Group.Value[0].Length * ($Group.Value.Count - 1)
    }
    Write-Host "[dedupe] $($DupGroups.Count | Measure-Object -Sum | Select-Object -ExpandProperty Sum) group(s), $([math]::Round($Waste/1MB,2)) MB reclaimable across $Count files." -ForegroundColor Yellow
} catch {
    Write-Host "[FAIL] Dedupe failed: $_" -ForegroundColor Red
}
