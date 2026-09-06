$RepoRoot = $PSScriptRoot
$SharedModule = Join-Path $RepoRoot 'SharedToolkit\SharedToolkit.psm1'

if (-not (Test-Path -LiteralPath $SharedModule -PathType Leaf)) {
    throw "SharedToolkit.psm1 not found: $SharedModule"
}

$lines = Get-Content -LiteralPath $SharedModule
for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match 'Export-ModuleMember') {
        Write-Host "Line $($i + 1): $($lines[$i])"
    }
}