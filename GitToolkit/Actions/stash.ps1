# Type: Action
# Description: Manages Git stashes (push, pop, list, apply, drop, show).
[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]
param($Config, [array]$Arguments)
$Parsed = Get-ActionArguments -Arguments $Arguments
$ArgsOnly = $Parsed.ArgsOnly
$Format = $Parsed.Format
$Force = $Parsed.Switches.Force
$C = Get-ToolkitColors

$Sub = if ($ArgsOnly[0]) { $ArgsOnly[0] } else { 'list' }
$Name = $ArgsOnly[1]
$Message = $ArgsOnly | Where-Object { $_ -match '^-m=' -or $_ -match '^--message=' } | ForEach-Object { $_ -replace '^-m=', '' -replace '^--message=', '' }
$IncludeUntracked = $ArgsOnly -contains '-u' -or $ArgsOnly -contains '--include-untracked'
$KeepIndex = $ArgsOnly -contains '-k' -or $ArgsOnly -contains '--keep-index'
$Index = $ArgsOnly | Where-Object { $_ -match '^--index=' } | ForEach-Object { $_ -replace '^--index=', '' }

$RepoPath = $Config.Path
Set-Location $RepoPath

switch ($Sub) {
    'list' {
        $Cmd = "git stash list"
        $Out = & $Cmd
        $Out | Format-ToolOutput -Format $Format
    }
    'push' {
        if (-not $Force -and -not $PSCmdlet.ShouldProcess("Git repository", "Create stash")) { return }
        $Cmd = "git stash push"
        if ($Message) { $Cmd += " -m `"$Message`"" }
        if ($IncludeUntracked) { $Cmd += " -u" }
        if ($KeepIndex) { $Cmd += " -k" }
        & $Cmd
    }
    'pop' {
        if (-not $Force -and -not $PSCmdlet.ShouldProcess("Git repository", "Pop stash")) { return }
        $Cmd = "git stash pop"
        if ($Index) { $Cmd += " --index=$Index" }
        & $Cmd
    }
    'apply' {
        if (-not $Force -and -not $PSCmdlet.ShouldProcess("Git repository", "Apply stash")) { return }
        $Cmd = "git stash apply"
        if ($Index) { $Cmd += " --index=$Index" }
        & $Cmd
    }
    'drop' {
        if (-not $Name) { Write-Host "$($C.Crit)[ERROR] Usage: stash drop <stash@{n}>$($C.Reset)"; return }
        if (-not $Force -and -not $PSCmdlet.ShouldProcess("Git repository", "Drop stash '$Name'")) { return }
        & git stash drop $Name
    }
    'show' {
        $Cmd = "git stash show"
        if ($Name) { $Cmd += " $Name" }
        $Cmd += " -p"
        $Out = & $Cmd
        $Out | Format-ToolOutput -Format $Format
    }
    default { Write-Host "$($C.Crit)[ERROR] Usage: stash [list|push|pop|apply|drop|show] ...$($C.Reset)" }
}