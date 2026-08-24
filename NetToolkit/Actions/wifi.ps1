# Type: Action
# Description: Lists saved WiFi profiles on the local machine and shows the cleartext password for a named profile.
param($Config, [array]$Arguments)
$Arguments = @($Arguments)
$C = Get-ToolkitColors
$Name = if ($Arguments[0]) { $Arguments[0] } else { $null }
Write-Host "[wifi] Saved profiles..." -ForegroundColor Cyan
try {
    $Profiles = netsh wlan show profiles | Select-String 'All User Profile' | ForEach-Object { ($_ -split ':')[1].Trim() }
    if (-not $Profiles) { Write-Host "  (no profiles found)" -ForegroundColor Gray; return }
    foreach ($P in $Profiles) {
        if (-not $Name -or $P -like "*$Name*") {
            Write-Host "  $($C.Str)$P$($C.Reset)" -ForegroundColor White
            if ($Name -and $P -like "*$Name*") {
                $Pwd = (netsh wlan show profile name="$P" key=clear | Select-String 'Key Content') -replace '^.+: ',''
                if ($Pwd) { Write-Host "    $($C.Warn)password:$($C.Reset) $($C.Ok)$Pwd$($C.Reset)" }
            }
        }
    }
} catch {
    Write-Host "[FAIL] WiFi enum failed: $_" -ForegroundColor Red
}

