# Type: Action
# Description: Searches file contents for a regex pattern (grep) under a root, showing file, line number, and matching text.
param($Config, [array]$Arguments)
$C = if ($global:ToolColors) { $global:ToolColors } else { [PSCustomObject]@{}}
$ArgsOnly = @($Arguments | Where-Object { $_ -notin @("-Force", "-f") })
$Pattern = if ($ArgsOnly[0]) { $ArgsOnly[0] } else { $null }
$Root = if ($ArgsOnly[1]) { $ArgsOnly[1] } else { $Config.Root }
$Filter = if ($ArgsOnly[2]) { $ArgsOnly[2] } else { "*.txt","*.log","*.ps1","*.csv","*.json","*.xml","*.md" }
if (-not $Pattern) { Write-Host "[ERROR] Provide a search pattern (regex)." -ForegroundColor Red ; return }
if (-not (Test-Path $Root)) { Write-Host "[ERROR] Root not found: $Root" -ForegroundColor Red ; return }
Write-Host "[grep] /$Pattern/ under $Root..." -ForegroundColor Cyan
try {
    $Files = Get-ChildItem -Path $Root -Recurse -File -Include $Filter -ErrorAction SilentlyContinue
    $Hits = 0
    foreach ($F in $Files) {
        try {
            $Lines = Get-Content $F.FullName -ErrorAction SilentlyContinue
            for ($i = 0; $i -lt $Lines.Count; $i++) {
                if ($Lines[$i] -match $Pattern) {
                    Write-Host "  $($C.Str)$($F.FullName):$($i+1)$($C.Reset) : $($C.Ok)$($Lines[$i].Trim())$($C.Reset)"
                    $Hits++
                }
            }
        } catch {}
    }
    Write-Host "[grep] $Hits match(es) in $($Files.Count) file(s)." -ForegroundColor Yellow
} catch {
    Write-Host "[FAIL] Grep failed: $_" -ForegroundColor Red
}
