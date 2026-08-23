# Type: Listener
# Description: Polls the remote host for a process; when it closes, runs the supplied chain argument and breaks.
param($Config, [array]$Arguments)

$ProcName = if ($Arguments[0]) { $Arguments[0] } else { $null }
$Chain = if ($Arguments[1]) { ($Arguments[1..($Arguments.Length-1)] -join " ") } else { $null }
if (-not $ProcName) { Write-Host "[Procwait Listener] Usage: <profile> procwait <ProcessName> [chain...]" -ForegroundColor Yellow ; return }
if (-not (Test-Connection -ComputerName $Config.IP -Count 1 -Quiet)) { Write-Host "[ABORT] Target offline." -ForegroundColor Yellow ; return }

$Auth = "-i `"$($Config.Key)`""
$Target = "$($Config.User)@$($Config.IP)"
Write-Host "[Procwait Listener] Waiting for '$ProcName' to close on $Target (Ctrl+C to stop)..." -ForegroundColor Cyan
try {
    while ($true) {
        $Running = & ssh -o ConnectTimeout=8 -o BatchMode=yes $Auth $Target "powershell -NoProfile -Command 'Get-Process -Name ''$ProcName'' -ErrorAction SilentlyContinue | Measure-Object | Select-Object -ExpandProperty Count'"
        if ("$Running".Trim() -eq "0") {
            Write-Host "[Procwait Listener] '$ProcName' has exited." -ForegroundColor Green
            if ($Chain) { Invoke-Expression $Chain }
            break
        }
        Start-Sleep -Seconds 3
    }
} finally {
    Write-Host "[Procwait Listener] Stopped." -ForegroundColor Yellow
}
