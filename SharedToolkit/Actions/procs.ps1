# Type: Action
# Description: Lists local processes, optionally filtered by a name fragment (second arg = top N count).
param($Config, [array]$Arguments)
$Filter = if ($Arguments[0]) { $Arguments[0] } else { $null }
$Top = if ($Arguments[1]) { [int]$Arguments[1] } else { 20 }
Get-Process | Where-Object { -not $Filter -or $_.Name -like "*$Filter*" } |
    Sort-Object CPU -Descending |
    Select-Object -First $Top Name, Id, @{n='CPU(s)';e={[math]::Round($_.CPU,1)}}, @{n='MB';e={[math]::Round($_.WorkingSet/1MB,0)}} |
    Format-Table -AutoSize | Out-Host
