# Type: Action
# Description: Scans common TCP ports on the target and reports which are open (optional custom port list as args).
param($Config, [array]$Arguments)
$Ports = if ($Arguments) { $Arguments | ForEach-Object { [int]$_ } } else { @(22,80,135,139,445,3389,5985,5986) }
if (-not (Test-Connection -ComputerName $Config.IP -Count 1 -Quiet)) { Write-Host "[ABORT] Target offline." -ForegroundColor Yellow ; return }
$C = if ($global:ToolColors) { $global:ToolColors } else { [PSCustomObject]@{} }
foreach ($p in $Ports) {
    $Open = Test-NetConnection -ComputerName $Config.IP -Port $p -InformationLevel Quiet -WarningAction SilentlyContinue
    Write-Host "Port $($C.Str)$p$($C.Reset) : $(if($Open){'OPEN'}else{'closed'})" -ForegroundColor (if($Open){'Green'}else{'Red'})
}
