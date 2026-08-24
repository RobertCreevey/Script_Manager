# Type: Action
# Description: Records changes to the repository.
[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]
param(
    $Config,
    [array]$Arguments,
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$Message,
    [switch]$Amend,
    [switch]$All,
    [switch]$Signoff
)

$C = Get-ToolkitColors
$Parsed = Get-ActionArguments -Arguments $Arguments
$Format = $Parsed.Format
$Force = $Parsed.Switches.Force

$RepoPath = $Config.Path
Set-Location $RepoPath
$Cmd = "git commit"
$Cmd += " -m `"$Message`""
if ($Amend) { $Cmd += " --amend" }
if ($All) { $Cmd += " -a" }
if ($Signoff) { $Cmd += " -s" }

& $Cmd
[PSCustomObject]@{ Action='commit'; Status='Completed' } | Format-ToolOutput -Format $Format
