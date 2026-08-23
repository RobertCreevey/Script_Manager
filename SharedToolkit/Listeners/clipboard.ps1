# Type: Listener
# Description: Watches the local clipboard for an IP address or file path; when matched, fires the supplied chain argument and breaks.
param($Config, [array]$Arguments)

$Chain = if ($Arguments) { $Arguments -join " " } else { $null }
$IPPattern = '^(?:\d{1,3}\.){3}\d{1,3}$'
$FilePattern = '\.(mp4|mp3|png|txt|ps1|zip)$'
Write-Host "[Clipboard Listener] Monitoring clipboard (Ctrl+C to stop)..." -ForegroundColor Cyan
try {
    while ($true) {
        $Text = Get-Clipboard -ErrorAction SilentlyContinue
        if ($Text -and ($Text -match $IPPattern -or $Text -match $FilePattern)) {
            Write-Host "[Clipboard Listener] Match: $Text" -ForegroundColor Green
            if ($Chain) { Invoke-Expression $Chain }
            Start-Sleep -Seconds 2
        }
        Start-Sleep -Milliseconds 500
    }
} finally {
    Write-Host "[Clipboard Listener] Stopped." -ForegroundColor Yellow
}
