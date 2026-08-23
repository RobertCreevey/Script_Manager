# Type: System
# Description: Appends tracking statements with profiles and timestamps to the local master event log file.
param($Config, [array]$Arguments)

$Message = $Arguments -join " "
$LogFile = "$Env:USERPROFILE\Documents\SSHToolkit_Events.log"
$Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$Context = if ($Config) { $Config.IP } else { "LocalSystem" }

 "[$Timestamp] [$Context] $Message" | Out-File $LogFile -Append
Write-Host "[$Timestamp] [$Context] $Message" -ForegroundColor Gray