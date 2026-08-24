# Type: Action
# Description: Force-plays a video file on the target's physical screen via Scheduled Task (bypasses Session 0 isolation).
param($Config, [array]$Arguments)
$C = if ($global:ToolColors) { $global:ToolColors } else { [PSCustomObject]@{}}
$ArgsOnly = @($Arguments | Where-Object { $_ -notin @("-Force", "-f", "-json", "-csv", "-raw", "-table", "-h", "-?") })
$Format = "table"
if ($Arguments -contains '-json') { $Format = 'json' } elseif ($Arguments -contains '-csv') { $Format = 'csv' } elseif ($Arguments -contains '-raw') { $Format = 'raw' }
$Path = $ArgsOnly[0]
$Player = if ($ArgsOnly[1]) { $ArgsOnly[1] } else { 'wmplayer' }  # wmplayer or edge
$Fullscreen = $Arguments -contains '-fs' -or $Arguments -contains '-fullscreen'

if (-not $Path) {
    Write-Host "$($C.Warn)[ERROR] Usage: play <path> [wmplayer|edge] [-fs]$($C.Reset)"
    Write-Host "$($C.Str)  Path must be accessible by the logged-in user (use C:\Users\Public\...)$($C.Reset)"
    return
}

if (-not (Assert-ToolkitAction -Verb "force-play video" -Command "play $Path" -Config $Config -Arguments $Arguments)) { return }

$IP = $Config.IP
$User = $Config.User
$Key = $Config.Key
$FileName = Split-Path $Path -Leaf
$PublicPath = "C:\Users\Public\$FileName"

Write-Host "[play] Copying to Public folder for cross-user access..." -ForegroundColor Cyan
$CopyCmd = "scp -i `"$Key`" `"$Path`" $User@$IP:`"$PublicPath`""
$ExitCode = & powershell -NoProfile -Command $CopyCmd; $LASTEXITCODE
if ($ExitCode -ne 0) { Write-Host "[FAIL] SCP copy failed." -ForegroundColor Red; return }

Write-Host "[play] Launching on target via Scheduled Task..." -ForegroundColor Cyan
$LoggedInUserCmd = "ssh $User@$IP -i $Key `(Get-CimInstance Win32_ComputerSystem).UserName`"
$LoggedInUser = & powershell -NoProfile -Command $LoggedInUserCmd

if ($Player -eq 'edge') {
    $EdgePath = 'file:///C:/Users/Public/' + $FileName
    $ActionArg = "--start-fullscreen `"`$EdgePath`"`"
    $Exe = "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
} else {
    $ActionArg = "`"`$PublicPath`" /fullscreen"
    $Exe = "C:\Program Files\Windows Media Player\wmplayer.exe"
}

$TaskScript = @"
`$Action = New-ScheduledTaskAction -Execute `"$Exe`" -Argument $ActionArg
`$Principal = New-ScheduledTaskPrincipal -UserId `"$LoggedInUser`" -LogonType Interactive
Register-ScheduledTask -TaskName `"ForceVideo_$FileName`" -Action `$Action -Principal `$Principal | Out-Null
Start-ScheduledTask -TaskName `"ForceVideo_$FileName`"
Start-Sleep -Seconds 3
Unregister-ScheduledTask -TaskName `"ForceVideo_$FileName`" -Confirm:`$false
"@

$Encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($TaskScript))
$SSHCmd = "ssh -i `$Key $User@$IP powershell -NoProfile -WindowStyle Hidden -EncodedCommand $Encoded"
& powershell -NoProfile -Command $SSHCmd

Write-Host "[play] Cleaning up remote file..." -ForegroundColor Cyan
$CleanupCmd = "ssh -i `"$Key`" $User@$IP Remove-Item `"$PublicPath`" -Force"
& powershell -NoProfile -Command $CleanupCmd

[PSCustomObject]@{ Action='play'; File=$FileName; Player=$Player; Status='Completed' } | Format-ToolOutput -Format $Format