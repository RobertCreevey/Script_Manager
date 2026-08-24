# Type: Action
# Description: Shows the status of all Windows Firewall profiles and the default inbound/outbound action.
param($Config, [array]$Arguments)
$C = Get-ToolkitColors
Write-Host "[firewall] Windows Firewall status..." -ForegroundColor Cyan
try {
    $Profiles = Get-NetFirewallProfile -ErrorAction SilentlyContinue
    foreach ($P in $Profiles) {
        $StatusColor = if ($P.Enabled) { 'Green' } else { 'Red' }
        Write-Host "  $($C.Sys)$($P.Name)$($C.Reset) : $(if($P.Enabled){'ON'}else{'OFF'})" -ForegroundColor $StatusColor
        Write-Host "    Default Inbound : $($C.Str)$($P.DefaultInboundAction)$($C.Reset)"
        Write-Host "    Default Outbound: $($C.Str)$($P.DefaultOutboundAction)$($C.Reset)"
    }
} catch {
    Write-Host "[FAIL] Could not read firewall status: $_" -ForegroundColor Red
}

