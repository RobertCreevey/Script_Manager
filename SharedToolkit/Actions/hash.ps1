# Type: Action
# Description: Computes and displays the cryptographic hash of a file (algorithm default SHA256, second arg).
param($Config, [array]$Arguments)
$Path = if ($Arguments[0]) { $Arguments[0] } else { $null }
$Algo = if ($Arguments[1]) { $Arguments[1] } else { "SHA256" }
if (-not $Path -or -not (Test-Path $Path)) { Write-Host "[ERROR] File not found: $Path" -ForegroundColor Red ; return }
$Hash = Get-FileHash -Path $Path -Algorithm $Algo
Write-Host "$($Hash.Algorithm): $($Hash.Hash)" -ForegroundColor Cyan
Write-Host "File: $($Hash.Path)" -ForegroundColor Gray
