# Type: Action
# Description: Opens a local file path or URL with the system default handler.
param($Config, [array]$Arguments)
$Target = if ($Arguments) { $Arguments -join " " } else { $null }
if (-not $Target) { Write-Host "[ERROR] Provide a path or URL." -ForegroundColor Red ; return }
if (-not (Test-Path $Target) -and $Target -notmatch '^https?://') { Write-Host "[ERROR] Not found: $Target" -ForegroundColor Red ; return }
Start-Process $Target
Write-Host "[open] Launched: $Target" -ForegroundColor Green
