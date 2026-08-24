# Type: Action
# Description: Shows command history with timestamps, context, and action. Supports search, replay by index, and clear.
param($Config, [array]$Arguments)
$ArgsOnly = @($Arguments | Where-Object { $_ -notin @("-Force", "-f") })
$C = if ($global:ToolColors) { $global:ToolColors } else { [PSCustomObject]@{}}
$Sub = if ($ArgsOnly[0]) { "$($ArgsOnly[0])".ToLower() } else { "show" }

if ($Sub -eq "clear") {
    try { "" | Set-Content $global:ToolCommandLog -Force; Write-Host "[OK] Command history cleared." -ForegroundColor Green } catch { Write-Host "$($C.Warn)[ERROR] Could not clear history: $_$($C.Reset)" }
    return
}

if ($Sub -eq "run" -and $ArgsOnly[1] -and $ArgsOnly[1] -match '^\d+$') {
    $TargetIdx = [int]$ArgsOnly[1]
    if (-not (Test-Path $global:ToolCommandLog)) { Write-Host "$($C.Warn)[ERROR] No command history found.$($C.Reset)" ; return }
    $Lines = Get-Content $global:ToolCommandLog | Where-Object { $_ -match '^\[\d{4}-\d{2}-\d{2}' }
    $TargetLine = $Lines[$TargetIdx - 1]
    if (-not $TargetLine) { Write-Host "$($C.Warn)[ERROR] No command at index $TargetIdx.$($C.Reset)" ; return }
    if ($TargetLine -match '^\[.+?\] \[(.+?)\] \[.+?\] (\w+) (.*)$') {
        $Ctx = $Matches[1]; $Action = $Matches[2]; $ArgsStr = $Matches[3]
        Write-Host "$($C.Info)Replaying #$TargetIdx : $($C.Action)$Action$($C.Reset) $($C.Str)$ArgsStr$($C.Reset)" -ForegroundColor Cyan
        $ArgsArr = @($ArgsStr -split ' ')
        try { Invoke-UniversalToolkitRouter -Action $Action -ForwardedArgs $ArgsArr } catch {
            Write-Host "$($C.Warn)[ERROR] Replay failed: $_$($C.Reset)"
        }
    }
    return
}

$SearchTerm = if ($Sub -eq "search" -and $ArgsOnly[1]) { $ArgsOnly[1] } else { $null }
$Count = if ($ArgsOnly | Where-Object { $_ -eq "-n" }) { $Nidx = $ArgsOnly.IndexOf("-n"); if ($Nidx -ge 0 -and $Nidx + 1 -lt $ArgsOnly.Count) { [int]$ArgsOnly[$Nidx + 1] } else { 20 } } else { 20 }

if (-not (Test-Path $global:ToolCommandLog)) { Write-Host "$($C.Warn)[ERROR] No command history found.$($C.Reset)" ; return }
$Lines = Get-Content $global:ToolCommandLog | Where-Object { $_ -match '^\[\d{4}-\d{2}-\d{2}' }
if ($SearchTerm) { $Lines = $Lines | Where-Object { $_ -like "*$SearchTerm*" } }
$Lines = $Lines | Select-Object -Last $Count

Write-Host ""
Write-Host "$($C.Sys)═══ COMMAND HISTORY ═══$($C.Reset)" -ForegroundColor White
if ($SearchTerm) { Write-Host "$($C.Str)filter: '$SearchTerm'$($C.Reset)" }
Write-Host ""
$Idx = 0
foreach ($Line in $Lines) {
    $Idx++
    if ($Line -match '^\[(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})\] \[(.+?)\] \[(.+?)\] (\w+) (.*)$') {
        Write-Host "  $($C.Param)$($Idx.ToString().PadLeft(3))$($C.Reset) $($C.Str)$($Matches[1])$($C.Reset) $($C.Host)$($Matches[2])$($C.Reset) $($C.Action)$($Matches[4])$($C.Reset) $($Matches[5])"
    }
}
Write-Host ""
Write-Host "$($C.Sys)Usage:$($C.Reset) $($C.Param)history run <n>$($C.Reset) replay | $($C.Param)history search <term>$($C.Reset) | $($C.Param)history clear$($C.Reset)"
Write-Host ""
