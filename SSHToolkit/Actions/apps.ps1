# Type: Action
# Description: Lists open applications with visible windows on the target.
param($Config, [array]$Arguments)
$C = Get-ToolkitColors
$ArgsOnly = @($Arguments | Where-Object { $_ -notin @("-Force", "-f", "-json", "-csv", "-raw", "-table", "-h", "-?") })
$Format = "table"
if ($Arguments -contains '-json') { $Format = 'json' } elseif ($Arguments -contains '-csv') { $Format = 'csv' } elseif ($Arguments -contains '-raw') { $Format = 'raw' }

$IP = $Config.IP
$User = $Config.User
$Key = $Config.Key

$Script = @"
Get-Process | Where-Object { `$_.MainWindowTitle -and `$_.MainWindowTitle.Length -gt 0 } | 
Select-Object Id, ProcessName, MainWindowTitle, @{Name='User';Expression={ (Get-WmiObject Win32_Process -Filter "ProcessId = `$($_.Id)").GetOwner().User } } |
Format-Table -AutoSize
"@
$Encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($Script))
$SSHCmd = "ssh -i `$Key $User@$IP powershell -NoProfile -WindowStyle Hidden -EncodedCommand $Encoded"
& powershell -NoProfile -Command $SSHCmd
