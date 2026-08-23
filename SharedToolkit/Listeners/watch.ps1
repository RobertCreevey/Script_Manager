# Type: Listener
# Description: Watches a directory for new files (optionally filtered by extension) and fires a chain per file (token {file} replaced).
param($Config, [array]$Arguments)
$Dir = if ($Arguments[0]) { $Arguments[0] } else { "C:\_Scripts" }
$Ext = if ($Arguments[1]) { $Arguments[1] } else { "*" }
$Chain = if ($Arguments[2]) { ($Arguments[2..($Arguments.Length-1)] -join " ") } else { $null }
if (-not (Test-Path $Dir)) { Write-Host "[watch] Directory missing: $Dir" -ForegroundColor Red ; return }
Write-Host "[watch] Monitoring $Dir (ext=$Ext) [Ctrl+C to stop]" -ForegroundColor Cyan
try {
    $Seen = @()
    while ($true) {
        $Files = Get-ChildItem $Dir -File -ErrorAction SilentlyContinue | Where-Object { $Ext -eq "*" -or $_.Extension -like $Ext }
        foreach ($f in $Files) {
            if ($f.FullName -notin $Seen) {
                $Seen += $f.FullName
                Write-Host "[watch] New: $($f.FullName)" -ForegroundColor Green
                if ($Chain) { $Cmd = $Chain -replace '\{file\}', $f.FullName ; Invoke-Expression $Cmd }
            }
        }
        Start-Sleep -Seconds 2
    }
} finally { Write-Host "[watch] Stopped." -ForegroundColor Yellow }
