# Type: Action
# Description: Scans TCP ports on a target (default profile IP) and reports open ports. Requires confirmation unless -Force.
param($Config, [array]$Arguments)
$C = if ($global:ToolColors) { $global:ToolColors } else { [PSCustomObject]@{}}
$ArgsOnly = @($Arguments | Where-Object { $_ -notin @("-Force", "-f") })
$Target = if ($ArgsOnly[0]) { $ArgsOnly[0] } else { $Config.IP }
if (-not $Target) { Write-Host "[ERROR] Provide a target IP or set profile IP." -ForegroundColor Red ; return }
$Ports = if ($ArgsOnly.Count -gt 1) { $ArgsOnly[1..($ArgsOnly.Count-1)] | ForEach-Object { [int]$_ } } else { @(22,80,135,139,445,3389,5985,5986,8080) }
if (-not (Assert-ToolkitAction -Verb "port scan ($($Ports.Count) ports)" -Command "Test-NetConnection to $($Ports -join ',') on $Target" -Config $Config -Arguments $Arguments)) { return }
Write-Host "[scan] $Target : $($Ports.Count) ports ..." -ForegroundColor Cyan
foreach ($p in $Ports) {
    $Open = Test-NetConnection -ComputerName $Target -Port $p -InformationLevel Quiet -WarningAction SilentlyContinue
    Write-Host "  Port $($C.Str)$p$($C.Reset) : $(if($Open){"$($C.Ok)OPEN"}else{"closed"})" -ForegroundColor (if($Open){'Green'}else{'Red'})
}
