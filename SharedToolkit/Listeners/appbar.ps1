# Type: Listener
# Description: Continuously updates the console window title with a compact realtime status (clock, CPU, RAM, context) — the 'top appbar'.
param($Config, [array]$Arguments)
$C = Get-ToolkitColors
$Interval = if ($Arguments[0] -and $Arguments[0] -match '^\d+$') { [int]$Arguments[0] } else { 3 }
$Ctx = if ($Config) { "$($Config.User)@$($Config.IP)" } else { "local" }
Write-Host "$($C.Warn)[appbar] Updating window title every ${Interval}s (Ctrl+C to stop).$($C.Reset)"
try {
    while ($true) {
        $Cpu = [math]::Round((Get-CimInstance Win32_Processor | Measure-Object -Property LoadPercentage -Average).Average, 0)
        $Os = Get-CimInstance Win32_OperatingSystem
        $RamFree = [math]::Round($Os.FreePhysicalMemory / 1MB, 1)
        $Online = if ($Config) { if (Test-Connection -ComputerName $Config.IP -Count 1 -Quiet) { "UP" } else { "DN" } } else { "UP" }
        $Host.UI.RawUI.WindowTitle = "SSHToolkit [$Ctx] $(Get-Date -Format HH:mm:ss) CPU:${Cpu}% RAM:${RamFree}GB $Online"
        Start-Sleep -Seconds $Interval
    }
} finally { Write-Host "$($C.Warn)[appbar] stopped.$($C.Reset)" }

