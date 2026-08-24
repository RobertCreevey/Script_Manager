# Type: Action
# Description: Shows active TCP connections and listening ports on the local machine with owning process names.
param($Config, [array]$Arguments)
$C = Get-ToolkitColors
Write-Host "[netstat] Active connections..." -ForegroundColor Cyan
try {
    $Connections = Get-NetTCPConnection -ErrorAction SilentlyContinue | Where-Object { $_.State -eq 'Listen' -or $_.State -eq 'Established' }
    if (-not $Connections) { Write-Host "  (no active connections)" -ForegroundColor Gray; return }
    $Connections | Sort-Object LocalAddress, LocalPort | ForEach-Object {
        $Proc = (Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue).ProcessName
        $Color = if ($_.State -eq 'Listen') { 'Yellow' } else { 'Green' }
        Write-Host "  $($C.Str)$($_.LocalAddress):$($_.LocalPort)$($C.Reset)  $($_.RemoteAddress):$($_.RemotePort)  [$($_.State)]  $Proc" -ForegroundColor $Color
    }
} catch {
    Write-Host "[FAIL] Could not read connections: $_" -ForegroundColor Red
}

