# Type: Action
# Description: SCP-copies a local media file to the remote host and triggers fullscreen playback via an interactive scheduled task (Session-0 safe), then erases all remote traces and logs locally.
param($Config, [array]$Arguments)

$FilePath = $Arguments -join " "
if (-not $FilePath -or -not (Test-Path $FilePath)) { Write-Host "[ERROR] Local source media not found at: '$FilePath'" -ForegroundColor Red ; return }
if (-not (Test-Connection -ComputerName $Config.IP -Count 1 -Quiet)) { Write-Host "[ABORT] Target offline." -ForegroundColor Yellow ; return }

& "$global:SharedToolkitPath\Actions\log.ps1" -Config $Config -Arguments @("Initiating fullscreen playback for: $FilePath")

$BaseName = [IO.Path]::GetFileName($FilePath)
$RemoteDest = "C:\Users\Public\$BaseName"
$Auth = "-i `"$($Config.Key)`""
$Target = "$($Config.User)@$($Config.IP)"

Write-Host "[*] Deploying $BaseName to $Target ..." -ForegroundColor Yellow
& scp $Auth "$FilePath" "${Target}:$RemoteDest"
if ($LASTEXITCODE -ne 0) { Write-Host "[FAIL] SCP transfer failed." -ForegroundColor Red ; return }
Write-Host "[PASS] Media deployed." -ForegroundColor Green

$ScriptName = "play_$BaseName.ps1"
$RemoteScript = "C:\Users\Public\$ScriptName"
$Wrapper = @"
`$base = '$BaseName'
`$rdest = '$RemoteDest'
`$user = (Get-CimInstance Win32_ComputerSystem).UserName
`$exe = 'C:\Program Files\Windows Media Player\wmplayer.exe'
if (Test-Path `$exe) {
    `$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -Command Start-Process '$exe' -ArgumentList '""`$rdest""','/fullscreen'"
} else {
    `$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -Command Start-Process 'msedge.exe' -ArgumentList 'file:///`$rdest'"
}
`$principal = New-ScheduledTaskPrincipal -UserId `$user -LogonType Interactive
Register-ScheduledTask -TaskName "PLAY_`$base" -Action `$action -Principal `$principal -Force | Out-Null
Start-ScheduledTask -TaskName "PLAY_`$base"
Start-Sleep -Seconds 6
Unregister-ScheduledTask -TaskName "PLAY_`$base" -Confirm:`$false
"@
$LocalScript = Join-Path $env:TEMP $ScriptName
$Wrapper | Out-File $LocalScript -Force

& scp $Auth "$LocalScript" "${Target}:$RemoteScript"
Invoke-Expression "ssh -o ConnectTimeout=8 -o BatchMode=yes $Auth $Target `"powershell -NoProfile -ExecutionPolicy Bypass -File '$RemoteScript'`""

Write-Host "[*] Playback triggered, cleaning up remote traces..." -ForegroundColor Cyan
Invoke-Expression "ssh -o ConnectTimeout=8 -o BatchMode=yes $Auth $Target `"powershell -NoProfile -Command 'if (Test-Path ''$RemoteScript'') { Remove-Item ''$RemoteScript'' -Force } ; if (Test-Path ''$RemoteDest'') { Remove-Item ''$RemoteDest'' -Force }'`""

Remove-Item $LocalScript -Force -ErrorAction SilentlyContinue
& "$global:SharedToolkitPath\Actions\log.ps1" -Config $Config -Arguments @("Playback finished and remote footprints erased.")
Write-Host "[DONE] Playback sequence complete, no trace left on target." -ForegroundColor Green
