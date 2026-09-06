$lines = Get-Content 'K:\_scripts\SharedToolkit_PowerShell_Module\SharedToolkit\SharedToolkit.psm1'
for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match 'Export-ModuleMember') {
        Write-Host "Line $($i+1): $($lines[$i])"
    }
}