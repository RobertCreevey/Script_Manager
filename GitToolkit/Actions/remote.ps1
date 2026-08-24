# Type: Action
# Description: Manages Git remotes (add, remove, rename, set-url, show, prune).
[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]
param($Config, [array]$Arguments)
$Parsed = Get-ActionArguments -Arguments $Arguments
$ArgsOnly = $Parsed.ArgsOnly
$Format = $Parsed.Format
$Force = $Parsed.Switches.Force
$C = Get-ToolkitColors

$Sub = if ($ArgsOnly[0]) { $ArgsOnly[0] } else { 'list' }
$Name = $ArgsOnly[1]
$Url = $ArgsOnly[2]
$NewName = $ArgsOnly[3]
$Prune = $ArgsOnly -contains '-p' -or $ArgsOnly -contains '--prune'
$Show = $ArgsOnly -contains '--show'
$Verbose = $ArgsOnly -contains '-v' -or $ArgsOnly -contains '--verbose'

$RepoPath = $Config.Path
Set-Location $RepoPath

switch ($Sub) {
    'list' {
        $Cmd = "git remote"
        if ($Verbose) { $Cmd += " -v" }
        $Out = & $Cmd
        $Out | Format-ToolOutput -Format $Format
    }
    'add' {
        if (-not $Name -or -not $Url) { Write-Host "$($C.Warn)[ERROR] Usage: remote add <name> <url>$($C.Reset)"; return }
        if (-not $Force -and -not $PSCmdlet.ShouldProcess("Git repository", "Add remote '$Name'")) { return }
        & git remote add $Name $Url
    }
    'remove' {
        if (-not $Name) { Write-Host "$($C.Warn)[ERROR] Usage: remote remove <name>$($C.Reset)"; return }
        if (-not $Force -and -not $PSCmdlet.ShouldProcess("Git repository", "Remove remote '$Name'")) { return }
        & git remote remove $Name
    }
    'rename' {
        if (-not $Name -or -not $NewName) { Write-Host "$($C.Warn)[ERROR] Usage: remote rename <old> <new>$($C.Reset)"; return }
        if (-not $Force -and -not $PSCmdlet.ShouldProcess("Git repository", "Rename remote '$Name' to '$NewName'")) { return }
        & git remote rename $Name $NewName
    }
    'set-url' {
        if (-not $Name -or -not $Url) { Write-Host "$($C.Warn)[ERROR] Usage: remote set-url <name> <new-url>$($C.Reset)"; return }
        if (-not $Force -and -not $PSCmdlet.ShouldProcess("Git repository", "Set URL for remote '$Name'")) { return }
        & git remote set-url $Name $Url
    }
    'show' {
        if (-not $Name) { Write-Host "$($C.Warn)[ERROR] Usage: remote show <name>$($C.Reset)"; return }
        $Out = & git remote show $Name
        $Out | Format-ToolOutput -Format $Format
    }
    'prune' {
        if (-not $Name) { Write-Host "$($C.Warn)[ERROR] Usage: remote prune <name>$($C.Reset)"; return }
        if (-not $Force -and -not $PSCmdlet.ShouldProcess("Git repository", "Prune remote '$Name'")) { return }
        & git remote prune $Name
    }
    default { Write-Host "$($C.Warn)[ERROR] Usage: remote [list|add|remove|rename|set-url|show|prune] ...$($C.Reset)" }
}