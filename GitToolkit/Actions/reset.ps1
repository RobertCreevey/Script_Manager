# Type: Action
# Description: Resets the current HEAD to a specified state.
[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='High')]
param($Config, [array]$Arguments)
$Parsed = Get-ActionArguments -Arguments $Arguments
$ArgsOnly = $Parsed.ArgsOnly
$Format = $Parsed.Format
$Force = $Parsed.Switches.Force
$C = Get-ToolkitColors

$Mode = if ($ArgsOnly[0] -in @('soft', 'mixed', 'hard', 'merge', 'keep')) { $ArgsOnly[0] } else { 'mixed' }
$Commit = if ($ArgsOnly[0] -notin @('soft', 'mixed', 'hard', 'merge', 'keep')) { $ArgsOnly[0] } else { $ArgsOnly[1] }
$Path = $ArgsOnly | Where-Object { $_ -notin @('soft', 'mixed', 'hard', 'merge', 'keep') -and $_ -ne $Commit } | Select-Object -First 1
$Soft = $ArgsOnly -contains '--soft'
$Hard = $ArgsOnly -contains '--hard'
$Mixed = $ArgsOnly -contains '--mixed'

$RepoPath = $Config.Path
Set-Location $RepoPath

if (-not $Force -and -not $PSCmdlet.ShouldProcess("Git repository", "Reset to $Mode${Commit:+ $Commit}")) { return }

$Cmd = "git reset"
if ($Soft) { $Cmd += " --soft" }
elseif ($Hard) { $Cmd += " --hard" }
elseif ($Mixed) { $Cmd += " --mixed" }
else { $Cmd += " --$Mode" }
if ($Commit) { $Cmd += " $Commit" }
if ($Path) { $Cmd += " -- $Path" }

& $Cmd