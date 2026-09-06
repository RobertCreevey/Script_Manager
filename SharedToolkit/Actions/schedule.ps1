# Type: Action
# Description: Schedules a chain to run automatically via Windows Task Scheduler at a set interval, lists scheduled chains, or removes them.
param($Config, [array]$Arguments)
$ArgsOnly = @($Arguments | Where-Object { $_ -notin @("-Force", "-f") })
$C = Get-ToolkitColors
$Sub = if ($ArgsOnly[0]) { $ArgsOnly[0].ToLower() } else { "list" }
$Prefix = "ToolkitChain_"

if ($Sub -eq "list") {
    $Tasks = Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object { $_.TaskName -like "$Prefix*" }
    Write-Host ""
    Write-Host "$($C.Sys)═══ SCHEDULED CHAINS ═══$($C.Reset)" -ForegroundColor White
    if (-not $Tasks) { Write-Host "  (none)" -ForegroundColor Gray }
    foreach ($T in $Tasks) {
        $State = $T.State
        $Triggers = ($T.Triggers | ForEach-Object { $_.Repetition.Interval }) -join ", "
        Write-Host "  $($C.Action)$($T.TaskName.Substring($Prefix.Length))$($C.Reset)  state:$($C.Str)$State$($C.Reset)  interval:$($C.Str)$Triggers$($C.Reset)"
    }
    Write-Host ""
    return
}

if ($Sub -eq "remove") {
    $Name = if ($ArgsOnly[1]) { $ArgsOnly[1] } else { $null }
    if (-not $Name) { Write-Host "$($C.Crit)[ERROR] Usage: schedule remove <chain-name>$($C.Reset)" ; return }
    $TaskName = "$Prefix$Name"
    $Task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if (-not $Task) { Write-Host "$($C.Crit)[ERROR] No scheduled task '$Name'.$($C.Reset)" ; return }
    if (-not (Request-ToolkitConfirmation -Verb "remove scheduled chain '$Name'" -Command "Unregister-ScheduledTask $TaskName" -Config $Config -Arguments @($Arguments, "-Force"))) { return }
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
    Write-Host "[OK] Removed scheduled chain '$Name'." -ForegroundColor Green
    return
}

if ($Sub -eq "add") {
    $Name = if ($ArgsOnly[1]) { $ArgsOnly[1] } else { $null }
    $IntervalMin = if ($ArgsOnly[2] -and $ArgsOnly[2] -match '^\d+$') { [int]$ArgsOnly[2] } else { $null }
    if (-not $Name -or -not $IntervalMin) { Write-Host "$($C.Crit)[ERROR] Usage: schedule add <chain-name> <interval-minutes>$($C.Reset)" ; return }
    $ChainFile = $null
    foreach ($d in @("$global:SSHToolkitPath\Chains", "$global:SharedToolkitPath\Chains")) { if (Test-Path "$d\$Name.json") { $ChainFile = "$d\$Name.json"; break } }
    if (-not $ChainFile) { Write-Host "$($C.Crit)[ERROR] Chain '$Name' not found.$($C.Reset)" ; return }
    $TaskName = "$Prefix$Name"
    $LoggedInUser = (Get-CimInstance Win32_ComputerSystem).UserName
    $ExecCmd = "pwsh -NoProfile -Command `"& { Import-Module SSHToolkit -ErrorAction SilentlyContinue; Invoke-UniversalToolkitRouter -Action 'chain' -ForwardedArgs @('run','$Name','-Force') }`""
    $Action = New-ScheduledTaskAction -Execute "pwsh" -Argument "-NoProfile -WindowStyle Hidden -Command $ExecCmd"
    $Trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes $IntervalMin) -RepetitionDuration (New-TimeSpan -Days 3650)
    $Principal = New-ScheduledTaskPrincipal -UserId $LoggedInUser -LogonType Interactive
    $Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
    if (-not (Request-ToolkitConfirmation -Verb "schedule chain '$Name'" -Command "every ${IntervalMin}min" -Config $Config -Arguments @($Arguments, "-Force") -Dangerous)) { return }
    try {
        Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Principal $Principal -Settings $Settings -Force | Out-Null
        Write-Host "[OK] Scheduled '$Name' every ${IntervalMin} minutes." -ForegroundColor Green
    } catch {
        Write-Host "$($C.Crit)[ERROR] Failed to schedule: $_$($C.Reset)"
    }
    return
}

Write-Host "$($C.Crit)[ERROR] Usage: schedule [add|list|remove] ...$($C.Reset)"


