# Type: Listener
# Description: Watches the Security event log for failed logon attempts (event 4625) and alerts with count and source IP.
param($Config, [array]$Arguments)
$Arguments = @($Arguments)
$C = if ($global:ToolColors) { $global:ToolColors } else { [PSCustomObject]@{}}
$Threshold = if ($Arguments[0] -and $Arguments[0] -match '^\d+$') { [int]$Arguments[0] } else { 5 }
$WindowMin = if ($Arguments[1] -and $Arguments[1] -match '^\d+$') { [int]$Arguments[1] } else { 5 }
Write-Host "[failwatch] Watching for >=$Threshold failed logons in ${WindowMin}min windows (Ctrl+C)..." -ForegroundColor Cyan
try {
    while ($true) {
        $Since = (Get-Date).AddMinutes(-$WindowMin)
        $Events = Get-WinEvent -FilterHashtable @{LogName='Security'; Id=4625; StartTime=$Since} -ErrorAction SilentlyContinue
        if ($Events.Count -ge $Threshold) {
            $Src = ($Events | Select-Object -First 1).Properties[19].Value
            Write-Host "[failwatch] $($C.Warn)$($Events.Count) failed logons since $($Since.ToString('HH:mm')) from $Src$($C.Reset)" -ForegroundColor Red
            & "$global:SharedToolkitPath\Actions\toast.ps1" -Config $Config -Arguments @("Brute Force?", "$($Events.Count) failed logons from $Src")
            [Console]::Beep(440, 500)
        }
        Start-Sleep -Seconds 30
    }
} catch { Write-Host "[failwatch] (event log access denied — run as admin)" -ForegroundColor Yellow }
