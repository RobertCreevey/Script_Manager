# Type: Action
# Description: Locks the target workstation (Win+L equivalent).
[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='High')]
param(
    $Config,
    [array]$Arguments
)

$Parsed = Get-ActionArguments -Arguments $Arguments
$ArgsOnly = $Parsed.ArgsOnly
$Format = $Parsed.Format
$Force = $Parsed.Switches.Force

$C = Get-ToolkitColors

if (-not $Force) {
    if ($PSCmdlet.ShouldProcess("Lock workstation on $($Config.IP)", "Lock")) {
        if (-not (Request-ToolkitConfirmation -Verb "lock workstation" -Command "lock" -Config $Config -Arguments $Arguments)) { return }
    } else {
        return
    }
}

$IP = $Config.IP
$User = $Config.User
$Key = $Config.Key

Write-Host "[lock] Locking target workstation..." -ForegroundColor Cyan
$SSHCmd = "ssh -i `$Key $User@$IP rundll32.exe user32.dll,LockWorkStation"
& powershell -NoProfile -Command $SSHCmd

Write-Host "[OK] Workstation locked" -ForegroundColor Green
[PSCustomObject]@{ Action='lock'; Status='Completed' } | Format-ToolOutput -Format $Format

