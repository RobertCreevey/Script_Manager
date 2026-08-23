# Type: Action
# Description: Shows an interactive Yes/No popup on the remote host (Session-0 safe) and returns the user's choice, then erases remote traces and logs.
param($Config, [array]$Arguments)

$Message = if ($Arguments[0]) { $Arguments[0] } else { "Proceed?" }
$Title = if ($Arguments[1]) { $Arguments[1] } else { "SSHToolkit" }
$TimeoutSec = if ($Arguments[2]) { [int]$Arguments[2] } else { 120 }

if (-not (Test-Connection -ComputerName $Config.IP -Count 1 -Quiet)) { Write-Host "[ABORT] Target offline." -ForegroundColor Yellow ; return }

$Auth = "-i `"$($Config.Key)`""
$Target = "$($Config.User)@$($Config.IP)"
$RespFile = "C:\Users\Public\popup_response.txt"

& "$global:SharedToolkitPath\Actions\log.ps1" -Config $Config -Arguments @("Popup shown on $($Target): $Message")

$Stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$ScriptName = "popup_$Stamp.ps1"
$RemoteScript = "C:\Users\Public\$ScriptName"
$Wrapper = @"
`$user = (Get-CimInstance Win32_ComputerSystem).UserName
`$popup = "Add-Type -AssemblyName Microsoft.VisualBasic; `$ws=New-Object -ComObject WScript.Shell; `$r=`$ws.Popup('$Message',0,'$Title',4+32); `$r | Out-File '$RespFile'"
`$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -Command `$popup"
`$principal = New-ScheduledTaskPrincipal -UserId `$user -LogonType Interactive
Register-ScheduledTask -TaskName "POPUP_$Stamp" -Action `$action -Principal `$principal -Force | Out-Null
Start-ScheduledTask -TaskName "POPUP_$Stamp"
"@
$LocalScript = Join-Path $env:TEMP $ScriptName
$Wrapper | Out-File $LocalScript -Force

& scp $Auth "$LocalScript" "${Target}:$RemoteScript"
Invoke-Expression "ssh -o ConnectTimeout=8 -o BatchMode=yes $Auth $Target `"powershell -NoProfile -ExecutionPolicy Bypass -File '$RemoteScript'`""

$Answer = $null
$Elapsed = 0
while ($Elapsed -lt $TimeoutSec) {
    $Found = & ssh -o ConnectTimeout=8 -o BatchMode=yes $Auth $Target "powershell -NoProfile -Command 'Test-Path ''$RespFile'''"
    if ("$Found".Trim() -eq "True") {
        $Answer = (& ssh -o ConnectTimeout=8 -o BatchMode=yes $Auth $Target "powershell -NoProfile -Command 'Get-Content ''$RespFile'''").Trim()
        break
    }
    Start-Sleep -Seconds 2
    $Elapsed += 2
}

Invoke-Expression "ssh -o ConnectTimeout=8 -o BatchMode=yes $Auth $Target `"powershell -NoProfile -Command 'if (Test-Path ''$RespFile'') { Remove-Item ''$RespFile'' -Force } ; Unregister-ScheduledTask -TaskName ''POPUP_$Stamp'' -Confirm:`$false'`""
Remove-Item $LocalScript -Force -ErrorAction SilentlyContinue

if ($Answer -eq "6") { Write-Host "[RESULT] User selected YES." -ForegroundColor Green }
elseif ($Answer -eq "7") { Write-Host "[RESULT] User selected NO." -ForegroundColor Yellow }
else { Write-Host "[RESULT] No response (timeout/closed)." -ForegroundColor Red }

& "$global:SharedToolkitPath\Actions\log.ps1" -Config $Config -Arguments @("Popup response: $Answer (6=Yes,7=No). Traces erased.")
