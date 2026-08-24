# Type: Action
# Description: Takes a silent screenshot on the target and downloads it via SCP.
param($Config, [array]$Arguments)
$C = if ($global:ToolColors) { $global:ToolColors } else { [PSCustomObject]@{}}
$ArgsOnly = @($Arguments | Where-Object { $_ -notin @("-Force", "-f", "-json", "-csv", "-raw", "-table", "-h", "-?") })
$Format = "table"
if ($Arguments -contains '-json') { $Format = 'json' } elseif ($Arguments -contains '-csv') { $Format = 'csv' } elseif ($Arguments -contains '-raw') { $Format = 'raw' }
$OutName = if ($ArgsOnly[0]) { $ArgsOnly[0] } else { "snap_$(Get-Date -Format 'yyyyMMdd_HHmmss').png" }

if (-not (Assert-ToolkitAction -Verb "take screenshot" -Command "snap" -Config $Config -Arguments $Arguments)) { return }

$IP = $Config.IP
$User = $Config.User
$Key = $Config.Key
$RemotePath = "C:\Users\Public\$OutName"
$LocalPath = "$env:USERPROFILE\Downloads\$OutName"

Write-Host "[snap] Capturing screenshot on target..." -ForegroundColor Cyan
$Script = @"
Add-Type -AssemblyName System.Windows.Forms
`$Bounds = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
`$Bitmap = New-Object System.Drawing.Bitmap `$Bounds.Width, `$Bounds.Height
`$Graphics = [System.Drawing.Graphics]::FromImage(`$Bitmap)
`$Graphics.CopyFromScreen(`$Bounds.Location, [System.Drawing.Point]::Empty, `$Bounds.Size)
`$Bitmap.Save(`"$RemotePath`")
"@
$Encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($Script))
$SSHCmd = "ssh -i `$Key $User@$IP powershell -NoProfile -WindowStyle Hidden -EncodedCommand $Encoded"
& powershell -NoProfile -Command $SSHCmd

Write-Host "[snap] Downloading..." -ForegroundColor Cyan
$ScpCmd = "scp -i `"$Key`" $User@$IP:`"$RemotePath`" `"$LocalPath`""
& powershell -NoProfile -Command $ScpCmd

Write-Host "[snap] Cleaning up remote..." -ForegroundColor Cyan
$CleanupCmd = "ssh -i `"$Key`" $User@$IP Remove-Item `"$RemotePath`" -Force"
& powershell -NoProfile -Command $CleanupCmd

if (Test-Path $LocalPath) {
    Write-Host "[OK] Saved to $LocalPath" -ForegroundColor Green
    [PSCustomObject]@{ Action='snap'; File=$OutName; LocalPath=$LocalPath; Status='Completed' } | Format-ToolOutput -Format $Format
} else {
    Write-Host "[FAIL] Screenshot not retrieved" -ForegroundColor Red
    [PSCustomObject]@{ Action='snap'; File=$OutName; Status='Failed' } | Format-ToolOutput -Format $Format
}