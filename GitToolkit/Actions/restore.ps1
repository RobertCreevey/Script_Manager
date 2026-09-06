# Type: Action
# Description: Restores working tree files or staged files.
[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]
param($Config, [array]$Arguments)
$Parsed = Get-ActionArguments -Arguments $Arguments
$ArgsOnly = $Parsed.ArgsOnly
$Format = $Parsed.Format
$Force = $Parsed.Switches.Force
$C = Get-ToolkitColors

$Paths = @($ArgsOnly | Where-Object { $_ -notin @('-s', '--staged', '-S', '--source', '-W', '--worktree', '-p', '--patch') })
$Staged = $ArgsOnly -contains '-s' -or $ArgsOnly -contains '--staged'
$Source = $ArgsOnly | Where-Object { $_ -match '^--source=' } | ForEach-Object { $_ -replace '^--source=', '' }
$Worktree = $ArgsOnly -contains '-W' -or $ArgsOnly -contains '--worktree'
$Patch = $ArgsOnly -contains '-p' -or $ArgsOnly -contains '--patch'

$RepoPath = $Config.Path
Set-Location $RepoPath

if (-not $Paths.Count -and -not $Staged) {
    Write-Host "$($C.Crit)[ERROR] Usage: restore <path>... [-s|--staged] [--source <commit>] [-W|--worktree] [-p]$($C.Reset)"
    return
}

if (-not $Force -and -not $PSCmdlet.ShouldProcess("Git repository", "Restore files")) { return }

$Cmd = "git restore"
if ($Staged) { $Cmd += " --staged" }
if ($Source) { $Cmd += " --source=$Source" }
if ($Worktree) { $Cmd += " --worktree" }
if ($Patch) { $Cmd += " --patch" }
if ($Paths.Count) { $Cmd += " $($Paths -join ' ')" }

& $Cmd