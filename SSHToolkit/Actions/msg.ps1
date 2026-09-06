# Type: Action
# Description: Sends a message popup to the target user via multiple methods (msg, WScript, Toast, WTSSendMessage).
param($Config, [array]$Arguments)
$C = Get-ToolkitColors
$ArgsOnly = @($Arguments | Where-Object { $_ -notin @("-Force", "-f", "-json", "-csv", "-raw", "-table", "-h", "-?") })
$Format = "table"
if ($Arguments -contains '-json') { $Format = 'json' } elseif ($Arguments -contains '-csv') { $Format = 'csv' } elseif ($Arguments -contains '-raw') { $Format = 'raw' }
$Method = if ($ArgsOnly[0]) { $ArgsOnly[0] } else { 'auto' }  # auto, msg, wscript, toast, wts
$Message = if ($ArgsOnly.Count -gt 1) { $ArgsOnly[1..($ArgsOnly.Count-1)] -join ' ' } else { "Message from admin" }
$Title = "System Notification"

if (-not (Request-ToolkitConfirmation -Verb "send message" -Command "msg $Method" -Config $Config -Arguments $Arguments)) { return }

$IP = $Config.IP
$User = $Config.User
$Key = $Config.Key

switch ($Method) {
    'msg' {
        Write-Host "[msg] Sending via msg.exe..." -ForegroundColor Cyan
        $SSHCmd = "ssh -i `$Key $User@$IP msg * `"$Message`""
        & powershell -NoProfile -Command $SSHCmd
    }
    'wscript' {
        Write-Host "[msg] Sending via WScript.Shell Popup (scheduled task)..." -ForegroundColor Cyan
        $Script = @"
`$wshell = New-Object -ComObject Wscript.Shell
`$wshell.Popup(`"$Message`", 0, `"$Title`", 64) | Out-Null
"@
        $Encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($Script))
        $SSHCmd = "ssh -i `$Key $User@$IP powershell -NoProfile -WindowStyle Hidden -EncodedCommand $Encoded"
        & powershell -NoProfile -Command $SSHCmd
    }
    'toast' {
        Write-Host "[msg] Sending via Windows Toast..." -ForegroundColor Cyan
        $Script = @"
[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")
`$Notification = New-Object System.Windows.Forms.NotifyIcon
`$Notification.Icon = [System.Drawing.SystemIcons]::Information
`$Notification.BalloonTipTitle = `"$Title`"
`$Notification.BalloonTipText = `"$Message`"
`$Notification.Visible = `$true
`$Notification.ShowBalloonTip(10000)
"@
        $Encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($Script))
        $SSHCmd = "ssh -i `$Key $User@$IP powershell -NoProfile -WindowStyle Hidden -EncodedCommand $Encoded"
        & powershell -NoProfile -Command $SSHCmd
    }
    'wts' {
        Write-Host "[msg] Sending via WTSSendMessage (Session 1)..." -ForegroundColor Cyan
        $Script = @"
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public class WTS {
    [DllImport("wtsapi32.dll", SetLastError = true)]
    public static extern bool WTSSendMessage(IntPtr hServer, int SessionId, String pTitle, int TitleLength, String pMessage, int MessageLength, int Style, int Timeout, out int pResponse, bool bWait);
}
'@
[WTS]::WTSSendMessage([IntPtr]::Zero, 1, `"$Title`", `$Title.Length, `"$Message`", `$Message.Length, 0, 0, [ref]0, `$false)
"@
        $Encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($Script))
        $SSHCmd = "ssh -i `$Key $User@$IP powershell -NoProfile -WindowStyle Hidden -EncodedCommand $Encoded"
        & powershell -NoProfile -Command $SSHCmd
    }
    default {  # auto - try wscript via scheduled task for visibility
        Write-Host "[msg] Auto: WScript Popup via Scheduled Task..." -ForegroundColor Cyan
        $Script = @"
`$wshell = New-Object -ComObject Wscript.Shell
`$wshell.Popup(`"$Message`", 0, `"$Title`", 64) | Out-Null
"@
        $Encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($Script))
        $LoggedInUser = "ssh $User@$IP -i $Key `(Get-CimInstance Win32_ComputerSystem).UserName"
        $LoggedInUser = & powershell -NoProfile -Command $LoggedInUser
        $TaskScript = @"
`$Action = New-ScheduledTaskAction -Execute `"powershell.exe`" -Argument `"-NoProfile -WindowStyle Hidden -EncodedCommand $Encoded`"
`$Principal = New-ScheduledTaskPrincipal -UserId `"$LoggedInUser`" -LogonType Interactive
Register-ScheduledTask -TaskName `"MsgPopup`" -Action `$Action -Principal `$Principal | Out-Null
Start-ScheduledTask -TaskName `"MsgPopup`"
Start-Sleep -Seconds 1
Unregister-ScheduledTask -TaskName `"MsgPopup`" -Confirm:`$false
"@
        $TaskEncoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($TaskScript))
        $SSHCmd = "ssh -i `$Key $User@$IP powershell -NoProfile -WindowStyle Hidden -EncodedCommand $TaskEncoded"
        & powershell -NoProfile -Command $SSHCmd
    }
}

[PSCustomObject]@{ Action='msg'; Method=$Method; Status='Sent' } | Format-ToolOutput -Format $Format

