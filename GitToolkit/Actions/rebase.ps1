# Type: Action
# Description: Rebases the current branch onto another branch.
[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='High')]
param($Config, [array]$Arguments)
$Parsed = Get-ActionArguments -Arguments $Arguments
$ArgsOnly = $Parsed.ArgsOnly
$Format = $Parsed.Format
$Force = $Parsed.Switches.Force
$C = Get-ToolkitColors

$Sub = if ($ArgsOnly[0]) { $ArgsOnly[0] } else { 'start' }
$Onto = $ArgsOnly | Where-Object { $_ -match '^--onto=' } | ForEach-Object { $_ -replace '^--onto=', '' }
$Upstream = $ArgsOnly[1]
$Interactive = $ArgsOnly -contains '-i' -or $ArgsOnly -contains '--interactive'
$Autosquash = $ArgsOnly -contains '--autosquash'
$Continue = $ArgsOnly -contains '--continue'
$Abort = $ArgsOnly -contains '--abort'
$Skip = $ArgsOnly -contains '--skip'

$RepoPath = $Config.Path
Set-Location $RepoPath

switch ($Sub) {
    'start' {
        if (-not $Upstream) { Write-Host "$($C.Crit)[ERROR] Usage: rebase start <upstream> [--onto <branch>] [-i] [--autosquash]$($C.Reset)"; return }
        if (-not $Force -and -not $PSCmdlet.ShouldProcess("Git repository", "Start rebase onto '$Upstream'")) { return }
        $Cmd = "git rebase"
        if ($Interactive) { $Cmd += " -i" }
        if ($Autosquash) { $Cmd += " --autosquash" }
        if ($Onto) { $Cmd += " --onto $Onto" }
        $Cmd += " $Upstream"
        & $Cmd
    }
    'continue' {
        if (-not $Force -and -not $PSCmdlet.ShouldProcess("Git repository", "Continue rebase")) { return }
        & git rebase --continue
    }
    'abort' {
        if (-not $Force -and -not $PSCmdlet.ShouldProcess("Git repository", "Abort rebase")) { return }
        & git rebase --abort
    }
    'skip' {
        if (-not $Force -and -not $PSCmdlet.ShouldProcess("Git repository", "Skip rebase commit")) { return }
        & git rebase --skip
    }
    default { Write-Host "$($C.Crit)[ERROR] Usage: rebase [start|continue|abort|skip] ...$($C.Reset)" }
}