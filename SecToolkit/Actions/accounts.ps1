# Type: Action
# Description: Lists local users and groups on the machine, showing name, enabled state, last logon, and group membership.
param($Config, [array]$Arguments)
$Arguments = @($Arguments)
$C = if ($global:ToolColors) { $global:ToolColors } else { [PSCustomObject]@{}}
$Mode = if ($Arguments[0]) { $Arguments[0].ToLower() } else { "users" }
Write-Host "[accounts] Local $Mode..." -ForegroundColor Cyan
try {
    if ($Mode -eq "groups" -or $Mode -eq "group") {
        $Groups = Get-LocalGroup -ErrorAction SilentlyContinue
        foreach ($G in $Groups) {
            $Members = (Get-LocalGroupMember -Group $G.Name -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name) -join ', '
            Write-Host "  $($C.Sys)$($G.Name)$($C.Reset) : $($C.Str)$($Members)$($C.Reset)"
        }
    } else {
        $Users = Get-LocalUser -ErrorAction SilentlyContinue
        foreach ($U in $Users) {
            $State = if ($U.Enabled) { "$($C.Ok)enabled" } else { "$($C.Warn)disabled" }
            $Color = if ($U.Enabled) { 'Green' } else { 'Red' }
            Write-Host "  $($C.Str)$($U.Name)$($C.Reset) $State  LastLogon: $($U.LastLogon)" -ForegroundColor $Color
        }
    }
} catch {
    Write-Host "[FAIL] Could not enumerate accounts: $_" -ForegroundColor Red
}
