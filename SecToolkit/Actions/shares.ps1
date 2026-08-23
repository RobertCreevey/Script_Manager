# Type: Action
# Description: Lists local SMB shares and their permissions, path, and current connection count.
param($Config, [array]$Arguments)
$C = if ($global:ToolColors) { $global:ToolColors } else { [PSCustomObject]@{}}
Write-Host "[shares] Local SMB shares..." -ForegroundColor Cyan
try {
    $Shares = Get-SmbShare -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne 'ADMIN$' -and $_.Name -ne 'IPC$' }
    if (-not $Shares) { Write-Host "  (no standard shares found)" -ForegroundColor Gray; return }
    foreach ($S in $Shares) {
        $Perms = (Get-SmbShareAccess -Name $S.Name -ErrorAction SilentlyContinue | ForEach-Object { "$($_.AccountName):$($_.AccessRight)" }) -join ', '
        Write-Host "  $($C.Sys)$($S.Name)$($C.Reset) : $($C.Str)$($S.Path)$($C.Reset) ($($S.CurrentUserCount) conn)"
        Write-Host "    $($C.Param)Permissions:$($C.Reset) $($Perms)"
    }
} catch {
    Write-Host "[FAIL] Could not enumerate shares: $_" -ForegroundColor Red
}
