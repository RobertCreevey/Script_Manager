# Type: Action
# Description: Merges a branch into the current branch.
[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='High')]
param($Config, [array]$Arguments)
$Parsed = Get-ActionArguments -Arguments $Arguments
$ArgsOnly = $Parsed.ArgsOnly
$Format = $Parsed.Format
$Force = $Parsed.Switches.Force
$C = Get-ToolkitColors

$Branch = $ArgsOnly[0]
$NoFF = $ArgsOnly -contains '--no-ff'
$Squash = $ArgsOnly -contains '--squash'
$Abort = $ArgsOnly -contains '--abort'
$Continue = $ArgsOnly -contains '--continue'
$Strategy = $ArgsOnly | Where-Object { $_ -match '^--strategy=' } | ForEach-Object { $_ -replace '^--strategy=', '' }
$StrategyOption = $ArgsOnly | Where-Object { $_ -match '^--strategy-option=' } | ForEach-Object { $_ -replace '^--strategy-option=', '' }

if (-not $Branch -and -not $Abort -and -not $Continue) {
    Write-Host "$($C.Warn)[ERROR] Usage: merge <branch> [--no-ff] [--squash] [--abort] [--continue] [--strategy STRATEGY]$($C.Reset)"
    return
}

$RepoPath = $Config.Path
Set-Location $RepoPath

if ($Abort) {
    if (-not $Force -and -not $PSCmdlet.ShouldProcess("Git repository", "Abort merge")) { return }
    & git merge --abort
    return
}
if ($Continue) {
    if (-not $Force -and -not $PSCmdlet.ShouldProcess("Git repository", "Continue merge")) { return }
    & git merge --continue
    return
}

if (-not $Force -and -not $PSCmdlet.ShouldProcess("Git repository", "Merge branch '$Branch'")) { return }

$Cmd = "git merge"
if ($NoFF) { $Cmd += " --no-ff" }
if ($Squash) { $Cmd += " --squash" }
if ($Strategy) { $Cmd += " --strategy=$Strategy" }
if ($StrategyOption) { $Cmd += " --strategy-option=$StrategyOption" }
$Cmd += " $Branch"

& $Cmd