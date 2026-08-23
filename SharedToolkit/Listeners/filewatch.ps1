# Type: Listener
# Description: Watches C:\_Scripts for new *.mp4 files and triggers playback of the newest one, then breaks.
param($Config, [array]$Arguments)

$WatchDir = if ($Arguments[0]) { $Arguments[0] } else { "C:\_Scripts" }
if (-not (Test-Path $WatchDir)) { Write-Host "[Filewatch Listener] Watch directory missing: $WatchDir" -ForegroundColor Red ; return }
Write-Host "[Filewatch Listener] Monitoring $WatchDir for *.mp4 (Ctrl+C to stop)..." -ForegroundColor Cyan
try {
    while ($true) {
        $Newest = Get-ChildItem $WatchDir -Filter *.mp4 -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($Newest) {
            Write-Host "[Filewatch Listener] New media: $($Newest.FullName)" -ForegroundColor Green
            if ($Config) { & "$global:SSHToolkitPath\Actions\play.ps1" -Config $Config -Arguments @($Newest.FullName) }
            else { Write-Host "[Filewatch Listener] No SSH profile context to play remotely." -ForegroundColor Yellow }
            Start-Sleep -Seconds 5
        }
        Start-Sleep -Seconds 2
    }
} finally {
    Write-Host "[Filewatch Listener] Stopped." -ForegroundColor Yellow
}
