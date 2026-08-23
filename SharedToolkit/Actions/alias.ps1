# Type: Action
# Description: Creates, lists, or deletes dynamic command aliases stored in the Shared Aliases folder (resolved automatically by the router).
param($Config, [array]$Arguments)
$Dir = "$global:SharedToolkitPath\Aliases"
if (-not (Test-Path $Dir)) { New-Item -ItemType Directory -Path $Dir -Force | Out-Null }
$Sub = if ($Arguments[0]) { $Arguments[0] } else { "list" }
if ($Sub -eq "list") {
    $Files = Get-ChildItem $Dir -Filter *.json -ErrorAction SilentlyContinue
    if (-not $Files) { Write-Host "(no aliases defined)" -ForegroundColor Gray ; return }
    foreach ($f in $Files) {
        $A = Get-Content $f.FullName | ConvertFrom-Json
        Write-Host "$($f.BaseName) -> $($A.Command)" -ForegroundColor Cyan
    }
    return
}
if ($Sub -eq "set") {
    $Name = $Arguments[1]
    $Command = ($Arguments[2..($Arguments.Length - 1)] -join " ")
    if (-not $Name -or -not $Command) { Write-Host "[ERROR] Usage: alias set <name> <command...>" -ForegroundColor Red ; return }
    [PSCustomObject]@{Command = $Command } | ConvertTo-Json | Out-File "$Dir\$Name.json" -Force
    Write-Host "[OK] Alias '$Name' -> '$Command'" -ForegroundColor Green
    return
}
if ($Sub -eq "del") {
    $Name = $Arguments[1]
    Remove-Item "$Dir\$Name.json" -Force -ErrorAction SilentlyContinue
    Write-Host "[OK] Removed alias '$Name'" -ForegroundColor Green
    return
}
Write-Host "[ERROR] Usage: alias [list|set|del] ..." -ForegroundColor Red
