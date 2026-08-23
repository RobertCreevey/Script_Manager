# Type: Action
# Description: Shows local IPv4 addresses, or tests a host:port when two arguments are supplied.
param($Config, [array]$Arguments)
$C = if ($global:ToolColors) { $global:ToolColors } else { [PSCustomObject]@{} }
if ($Arguments.Count -ge 2) {
    $Host2 = $Arguments[0]; $Port = [int]$Arguments[1]
    $Open = Test-NetConnection -ComputerName $Host2 -Port $Port -InformationLevel Quiet -WarningAction SilentlyContinue
    Write-Host "Port $Port on $($C.Str)$Host2$($C.Reset) : $(if($Open){'OPEN'}else{'CLOSED'})" -ForegroundColor (if($Open){'Green'}else{'Red'})
    return
}
Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.InterfaceAlias -notmatch 'Loopback' } | ForEach-Object {
    Write-Host "$($C.File)$($_.InterfaceAlias)$($C.Reset) : $($C.Str)$($_.IPAddress)$($C.Reset)"
}
