# Type: Action
# Description: Manages Git tags (create, list, delete, verify).
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
$Annotated = $ArgsOnly -contains '-a' -or $ArgsOnly -contains '--annotate'
$Delete = $ArgsOnly -contains '-d' -or $ArgsOnly -contains '--delete'
$Verify = $ArgsOnly -contains '-v' -or $ArgsOnly -contains '--verify'
$List = $ArgsOnly -contains '-l' -or $ArgsOnly -contains '--list'
$Pattern = $ArgsOnly | Where-Object { $_ -match '^--pattern=' } | ForEach-Object { $_ -replace '^--pattern=', '' }
$PointsAt = $ArgsOnly | Where-Object { $_ -match '^--points-at=' } | ForEach-Object { $_ -replace '^--points-at=', '' }

$RepoPath = $Config.Path
Set-Location $RepoPath

switch ($Sub) {
    'list' {
        $Cmd = "git tag"
        if ($List) { $Cmd += " -l" }
        if ($Pattern) { $Cmd += " $Pattern" }
        if ($PointsAt) { $Cmd += " --points-at $PointsAt" }
        $Out = & $Cmd
        $Out | Format-ToolOutput -Format $Format
    }
    'create' {
        if (-not $Name) { Write-Host "$($C.Warn)[ERROR] Usage: tag create <name> [-m message] [-a]$($C.Reset)"; return }
        if (-not $Force -and -not $PSCmdlet.ShouldProcess("Git repository", "Create tag '$Name'")) { return }
        $Cmd = "git tag"
        if ($Annotated -or $Message) { $Cmd += " -a" }
        if ($Message) { $Cmd += " -m `"$Message`"" }
        $Cmd += " $Name"
        & $Cmd
    }
    'delete' {
        if (-not $Name) { Write-Host "$($C.Warn)[ERROR] Usage: tag delete <name>$($C.Reset)"; return }
        if (-not $Force -and -not $PSCmdlet.ShouldProcess("Git repository", "Delete tag '$Name'")) { return }
        & git tag -d $Name
    }
    'verify' {
        if (-not $Name) { Write-Host "$($C.Warn)[ERROR] Usage: tag verify <name>$($C.Reset)"; return }
        & git tag -v $Name
    }
    default { Write-Host "$($C.Warn)[ERROR] Usage: tag [list|create|delete|verify] ...$($C.Reset)" }
}