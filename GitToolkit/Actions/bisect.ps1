# Type: Action
# Description: Uses binary search to find the commit that introduced a bug.
[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]
param($Config, [array]$Arguments)
$Parsed = Get-ActionArguments -Arguments $Arguments
$ArgsOnly = $Parsed.ArgsOnly
$Format = $Parsed.Format
$Force = $Parsed.Switches.Force
$C = Get-ToolkitColors

$Sub = if ($ArgsOnly[0]) { $ArgsOnly[0] } else { 'help' }
$Bad = $ArgsOnly | Where-Object { $_ -match '^--bad=' } | ForEach-Object { $_ -replace '^--bad=', '' }
$Good = $ArgsOnly | Where-Object { $_ -match '^--good=' } | ForEach-Object { $_ -replace '^--good=', '' }
$Skip = $ArgsOnly | Where-Object { $_ -match '^--skip=' } | ForEach-Object { $_ -replace '^--skip=', '' }
$Term = $ArgsOnly -contains '--term'
$TermBad = $ArgsOnly | Where-Object { $_ -match '^--term-bad=' } | ForEach-Object { $_ -replace '^--term-bad=', '' }
$TermGood = $ArgsOnly | Where-Object { $_ -match '^--term-good=' } | ForEach-Object { $_ -replace '^--term-good=', '' }

$RepoPath = $Config.Path
Set-Location $RepoPath

switch ($Sub) {
    'start' {
        if (-not $Force -and -not $PSCmdlet.ShouldProcess("Git repository", "Start bisect")) { return }
        $Cmd = "git bisect start"
        if ($Bad) { $Cmd += " --bad=$Bad" }
        if ($Good) { $Cmd += " --good=$Good" }
        & $Cmd
    }
    'bad' {
        $Cmd = "git bisect bad"
        if ($Bad) { $Cmd += " $Bad" }
        & $Cmd
    }
    'good' {
        $Cmd = "git bisect good"
        if ($Good) { $Cmd += " $Good" }
        & $Cmd
    }
    'skip' {
        if (-not $Skip) { Write-Host "$($C.Crit)[ERROR] Usage: bisect skip <commit>$($C.Reset)"; return }
        $Cmd = "git bisect skip $Skip"
        & $Cmd
    }
    'reset' {
        if (-not $Force -and -not $PSCmdlet.ShouldProcess("Git repository", "Reset bisect")) { return }
        & git bisect reset
    }
    'log' {
        $Out = & git bisect log
        $Out | Format-ToolOutput -Format $Format
    }
    'replay' {
        $File = $ArgsOnly[1]
        if (-not $File) { Write-Host "$($C.Crit)[ERROR] Usage: bisect replay <file>$($C.Reset)"; return }
        & git bisect replay $File
    }
    'run' {
        $Script = $ArgsOnly[1..($ArgsOnly.Count-1)] -join ' '
        if (-not $Script) { Write-Host "$($C.Crit)[ERROR] Usage: bisect run <command>$($C.Reset)"; return }
        if (-not $Force -and -not $PSCmdlet.ShouldProcess("Git repository", "Run bisect with command")) { return }
        & git bisect run $Script
    }
    'terms' {
        if ($Term) {
            if (-not $TermBad -or -not $TermGood) { Write-Host "$($C.Crit)[ERROR] Usage: bisect terms --term-bad <bad> --term-good <good>$($C.Reset)"; return }
            & git bisect terms --term-bad $TermBad --term-good $TermGood
        } else {
            & git bisect terms
        }
    }
    default { Write-Host "$($C.Crit)[ERROR] Usage: bisect [start|bad|good|skip|reset|log|replay|run|terms] ...$($C.Reset)" }
}