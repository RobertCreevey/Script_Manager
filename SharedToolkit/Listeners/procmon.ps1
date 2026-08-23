# Type: Listener
# Description: Watches a local process for start or exit and fires a chain command when the event occurs.
param($Config, [array]$Arguments)
$ProcName = if ($Arguments[0]) { $Arguments[0] } else { $null }
$When = if ($Arguments[1]) { $Arguments[1] } else { "exit" }
$Chain = if ($Arguments[2]) { ($Arguments[2..($Arguments.Length-1)] -join " ") } else { $null }
if (-not $ProcName) { Write-Host "[procmon] Usage: procmon <process> [start|exit] [chain]" -ForegroundColor Yellow ; return }
Write-Host "[procmon] Watching '$ProcName' for '$When' [Ctrl+C to stop]" -ForegroundColor Cyan
$Seen = [bool](Get-Process -Name $ProcName -ErrorAction SilentlyContinue)
try {
    while ($true) {
        $Running = [bool](Get-Process -Name $ProcName -ErrorAction SilentlyContinue)
        if ($When -eq "exit" -and $Seen -and -not $Running) {
            Write-Host "[procmon] $ProcName exited." -ForegroundColor Green
            if ($Chain) { Invoke-Expression $Chain }
            break
        }
        if ($When -eq "start" -and -not $Seen -and $Running) {
            Write-Host "[procmon] $ProcName started." -ForegroundColor Green
            if ($Chain) { Invoke-Expression $Chain }
            break
        }
        $Seen = $Running
        Start-Sleep -Seconds 2
    }
} finally { Write-Host "[procmon] Stopped." -ForegroundColor Yellow }
