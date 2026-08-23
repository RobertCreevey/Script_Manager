# Type: Action
# Description: Displays a native Windows system tray balloon tip notification toast with custom title and message body.
param($Config, [array]$Arguments)

$Title = if ($Arguments[0]) { $Arguments[0] } else { "SSHToolkit Alert" }
$Message = if ($Arguments[1]) { $Arguments[1] } else { "Action executed successfully." }

[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")
$Toast = New-Object System.Windows.Forms.NotifyIcon
$Toast.Icon = [System.Drawing.SystemIcons]::Information
$Toast.BalloonTipTitle = $Title
$Toast.BalloonTipText = $Message
$Toast.Visible = $true
$Toast.ShowBalloonTip(10000)

if (Get-Module -ListAvailable ThreadJob) {
    Start-ThreadJob -ScriptBlock { Start-Sleep -Seconds 7 ; $args[0].Dispose() } -ArgumentList $Toast | Out-Null
} else {
    Start-Sleep -Seconds 7
    $Toast.Dispose()
}
