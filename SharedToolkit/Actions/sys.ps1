# Type: Action
# Description: Displays a local system summary: host, OS, CPU, memory, uptime and free disk space.
param($Config, [array]$Arguments)
$C = Get-ToolkitColors
$OS = Get-CimInstance Win32_OperatingSystem
$CS = Get-CimInstance Win32_ComputerSystem
$CPU = Get-CimInstance Win32_Processor | Select-Object -First 1
$Up = (Get-Date) - $OS.LastBootUpTime
Write-Host "Host : $($C.Host)$($CS.Name)$($C.Reset)" -ForegroundColor White
Write-Host "OS   : $($C.Str)$($OS.Caption) ($($OS.Version))$($C.Reset)"
Write-Host "CPU  : $($C.Str)$($CPU.Name)$($C.Reset)"
Write-Host "RAM  : $($C.Str)$([math]::Round($CS.TotalPhysicalMemory/1GB,1)) GB$($C.Reset)"
Write-Host "Up   : $($C.Str)$($Up.Days)d $($Up.Hours)h $($Up.Minutes)m$($C.Reset)"
Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" | ForEach-Object {
    Write-Host "Disk $($_.DeviceID) : $($C.File)$([math]::Round($_.FreeSpace/1GB,1)) GB free / $([math]::Round($_.Size/1GB,1)) GB$($C.Reset)"
}

