# Type: Action
# Description: Removes untracked files from the working tree.
[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='High')]
param($Config, [array]$Arguments)
$Parsed = Get-ActionArguments -Arguments $Arguments
$ArgsOnly = $Parsed.ArgsOnly
$Format = $Parsed.Format
$Force = $Parsed.Switches.Force
$C = Get-ToolkitColors

$ForceFlag = $ArgsOnly -contains '-f' -or $ArgsOnly -contains '--force'
$Directories = $ArgsOnly -contains '-d' -or $ArgsOnly -contains '--directories'
$Ignored = $ArgsOnly -contains '-x' -or $ArgsOnly -contains '--ignored'
$Exclude = $ArgsOnly | Where-Object { $_ -match '^--exclude=' } | ForEach-Object { $_ -replace '^--exclude=', '' }
$DryRun = $ArgsOnly -contains '-n' -or $ArgsOnly -contains '--dry-run'

$RepoPath = $Config.Path
Set-Location $RepoPath

if (-not $Force -and -not $PSCmdlet.ShouldProcess("Git repository", "Clean untracked files")) { return }

$Cmd = "git clean"
if ($ForceFlag) { $Cmd += " -f" }
if ($Directories) { $Cmd += " -d" }
if ($Ignored) { $Cmd += " -x" }
if ($Exclude) { $Cmd += " --exclude=$Exclude" }
if ($DryRun) { $Cmd += " -n" }

& $Cmd