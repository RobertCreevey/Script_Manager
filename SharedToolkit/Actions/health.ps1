# Type: Action
# Description: Health check dashboard for all toolkits and system status.
param($Config, [array]$Arguments)

$C = if ($global:ToolColors) { $global:ToolColors } else { [PSCustomObject]@{}}
$Format = "table"
if ($Arguments -contains '-json') { $Format = 'json' }
elseif ($Arguments -contains '-csv') { $Format = 'csv' }
elseif ($Arguments -contains '-raw') { $Format = 'raw' }

$Results = @()

# System Health
$Cpu = [math]::Round((Get-CimInstance Win32_Processor | Measure-Object -Property LoadPercentage -Average).Average, 0)
$Os = Get-CimInstance Win32_OperatingSystem
$Cs = Get-CimInstance Win32_ComputerSystem
$RamFree = [math]::Round($Os.FreePhysicalMemory / 1MB, 1)
$RamTotal = [math]::Round($Cs.TotalPhysicalMemory / 1GB, 1)
$RamUsedPct = [math]::Round((1 - $Os.FreePhysicalMemory / $Os.TotalVisibleMemorySize) * 100, 1)
$Disk = Get-CimInstance Win32_LogicalDisk | Where-Object { $_.DriveType -eq 3 } | Select-Object DeviceID, @{Name='FreeGB';Expression={[math]::Round($_.FreeSpace/1GB,1)}}, @{Name='TotalGB';Expression={[math]::Round($_.Size/1GB,1)}}, @{Name='UsedPct';Expression={[math]::Round((1-$_.FreeSpace/$_.Size)*100,1)}}

$Results += [PSCustomObject]@{ Component = 'System'; Check = 'CPU Load'; Value = "$Cpu%"; Status = if ($Cpu -gt 90) { 'Critical' } elseif ($Cpu -gt 70) { 'Warning' } else { 'OK' } }
$Results += [PSCustomObject]@{ Component = 'System'; Check = 'RAM'; Value = "$RamUsedPct% ($RamFree GB free of $RamTotal GB)"; Status = if ($RamUsedPct -gt 90) { 'Critical' } elseif ($RamUsedPct -gt 80) { 'Warning' } else { 'OK' } }
$Disk | ForEach-Object {
    $Results += [PSCustomObject]@{ Component = 'System'; Check = "Disk $($_.DeviceID)"; Value = "$($_.UsedPct)% ($($_.FreeGB) GB free of $($_.TotalGB) GB)"; Status = if ($_.UsedPct -gt 90) { 'Critical' } elseif ($_.UsedPct -gt 80) { 'Warning' } else { 'OK' } }
}

# Toolkit Health
$Toolkits = @("SSHToolkit", "NetToolkit", "MediaToolkit", "SecToolkit", "FileToolkit", "SharedToolkit")
foreach ($Toolkit in $Toolkits) {
    $ModulePath = "$env:USERPROFILE\Documents\PowerShell\Modules\$Toolkit\$Toolkit.psm1"
    if (Test-Path $ModulePath) {
        $Results += [PSCustomObject]@{ Component = $Toolkit; Check = 'Module'; Value = 'Installed'; Status = 'OK' }
        $ActionsPath = "$env:USERPROFILE\Documents\PowerShell\Modules\$Toolkit\Actions"
        if (Test-Path $ActionsPath) {
            $ActionCount = (Get-ChildItem "$ActionsPath\*.ps1" -ErrorAction SilentlyContinue).Count
            $Results += [PSCustomObject]@{ Component = $Toolkit; Check = 'Actions'; Value = "$ActionCount actions"; Status = 'OK' }
        }
        $ProfilesPath = "$env:USERPROFILE\Documents\PowerShell\Modules\$Toolkit\Profiles"
        if (Test-Path $ProfilesPath) {
            $ProfileCount = (Get-ChildItem "$ProfilesPath\*.json" -ErrorAction SilentlyContinue).Count
            $Results += [PSCustomObject]@{ Component = $Toolkit; Check = 'Profiles'; Value = "$ProfileCount profiles"; Status = 'OK' }
        }
    } else {
        $Results += [PSCustomObject]@{ Component = $Toolkit; Check = 'Module'; Value = 'Not Installed'; Status = 'Missing' }
    }
}

# Network connectivity
$Targets = @('8.8.8.8', '1.1.1.1')
foreach ($Target in $Targets) {
    $Ping = Test-Connection -ComputerName $Target -Count 1 -Quiet -ErrorAction SilentlyContinue
    $Results += [PSCustomObject]@{ Component = 'Network'; Check = "DNS $Target"; Value = if ($Ping) { 'Reachable' } else { 'Unreachable' }; Status = if ($Ping) { 'OK' } else { 'Warning' } }
}

# Logs
$LogPath = "$env:USERPROFILE\Documents\SSHToolkit_CommandHistory.log"
$EventPath = "$env:USERPROFILE\Documents\SSHToolkit_Events.log"
$LogSize = if (Test-Path $LogPath) { [math]::Round((Get-Item $LogPath).Length / 1KB, 1) } else { 0 }
$EventSize = if (Test-Path $EventPath) { [math]::Round((Get-Item $EventPath).Length / 1KB, 1) } else { 0 }
$Results += [PSCustomObject]@{ Component = 'Logs'; Check = 'Command Log'; Value = "$LogSize KB"; Status = if ($LogSize -gt 10240) { 'Warning' } else { 'OK' } }
$Results += [PSCustomObject]@{ Component = 'Logs'; Check = 'Event Log'; Value = "$EventSize KB"; Status = if ($EventSize -gt 10240) { 'Warning' } else { 'OK' } }

# Output
if ($Format -eq 'json') {
    $Results | ConvertTo-Json -Depth 3
} elseif ($Format -eq 'csv') {
    $Results | ConvertTo-Csv -NoTypeInformation
} elseif ($Format -eq 'raw') {
    $Results | ForEach-Object { "$($_.Component) | $($_.Check) | $($_.Value) | $($_.Status)" }
} else {
    $Results | Format-Table -AutoSize -Property Component, Check, Value, Status
    Write-Host ""
    Write-Host "$($C.Muted)Run with -json, -csv, or -raw for machine-readable output$($C.Reset)"
}