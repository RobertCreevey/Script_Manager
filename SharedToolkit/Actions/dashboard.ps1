# Type: Action
# Description: Live realtime status dashboard (clock, CPU, RAM, context, target online, recent events) refreshed until Ctrl+C.
param($Config, [array]$Arguments)
$C = if ($global:ToolColors) { $global:ToolColors } else { [PSCustomObject]@{} }
$Interval = if ($Arguments[0] -and $Arguments[0] -match '^\d+$') { [int]$Arguments[0] } else { 2 }
Write-Host "$($C.Warn)[dashboard] Refresh every ${Interval}s. Press Ctrl+C to exit.$($C.Reset)"
$Ctx = if ($Config) { "$($C.Host)$($Config.User)@$($Config.IP)$($C.Reset)" } else { "$($C.File)local$($C.Reset)" }
$Builtins = @('online', 'ssh', 'config', 'help', 'chain', 'alias', 'theme', 'events', 'notify', 'dashboard', 'appbar')
try {
    while ($true) {
        $Cpu = [math]::Round((Get-CimInstance Win32_Processor | Measure-Object -Property LoadPercentage -Average).Average, 0)
        $Os = Get-CimInstance Win32_OperatingSystem
        $Cs = Get-CimInstance Win32_ComputerSystem
        $RamFree = [math]::Round($Os.FreePhysicalMemory / 1MB, 1)
        $RamTotal = [math]::Round($Cs.TotalPhysicalMemory / 1GB, 1)
        $CpuBar = ('#' * [math]::Min(20, [math]::Round($Cpu / 5))) + ('-' * (20 - [math]::Min(20, [math]::Round($Cpu / 5))))
        $RamBar = ('#' * [math]::Min(20, [math]::Round($RamFree / $RamTotal * 20))) + ('-' * (20 - [math]::Min(20, [math]::Round($RamFree / $RamTotal * 20))))
        $Online = if ($Config) { if (Test-Connection -ComputerName $Config.IP -Count 1 -Quiet) { "$($C.Ok)ONLINE" } else { "$($C.Warn)OFFLINE" } } else { "$($C.Info)n/a" }
        $Last = if ($global:ToolEvents.Count) { "$($global:ToolEvents[-1].Name) $($global:ToolEvents[-1].Data)" } else { "-" }
        Clear-Host
        Write-Host "$($C.Sys)==== SSHToolkit Live Dashboard ====$($C.Reset)"
        Write-Host "Clock   : $($C.Str)$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')$($C.Reset)"
        Write-Host "Context : $Ctx"
        Write-Host "Target  : $Online"
        Write-Host "CPU     : [$CpuBar] ${Cpu}%"
        Write-Host "RAM     : [$RamBar] ${RamFree}GB / ${RamTotal}GB free"
        Write-Host "LastEvt : $($C.Info)$Last$($C.Reset)"
        Write-Host "$($C.Sys)------------------------------------$($C.Reset)"
        Write-Host "Quick: $($C.Action)$($Builtins -join '  ')$($C.Reset)"
        Start-Sleep -Seconds $Interval
    }
} finally { Write-Host "$($C.Warn)[dashboard] stopped.$($C.Reset)" }
