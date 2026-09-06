# Type: Action
# Description: Manages branches (list, create, delete, rename, switch).
[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]
param($Config, [array]$Arguments)
$Parsed = Get-ActionArguments -Arguments $Arguments
$ArgsOnly = $Parsed.ArgsOnly
$Format = $Parsed.Format
$Force = $Parsed.Switches.Force
$C = Get-ToolkitColors

$Sub = if ($ArgsOnly[0]) { $ArgsOnly[0] } else { 'list' }
$Name = $ArgsOnly[1]
$StartPoint = $ArgsOnly[2]
$Delete = $ArgsOnly -contains '-d' -or $ArgsOnly -contains '--delete'
$ForceDelete = $ArgsOnly -contains '-D' -or $ArgsOnly -contains '--force'
$Move = $ArgsOnly -contains '-m' -or $ArgsOnly -contains '--move'
$List = $ArgsOnly -contains '-l' -or $ArgsOnly -contains '--list'
$All = $ArgsOnly -contains '-a' -or $ArgsOnly -contains '--all'
$Remote = $ArgsOnly -contains '-r' -or $ArgsOnly -contains '--remote'
$Contains = $ArgsOnly | Where-Object { $_ -match '^--contains=' } | ForEach-Object { $_ -replace '^--contains=', '' }
$Merged = $ArgsOnly -contains '--merged'
$NoMerged = $ArgsOnly -contains '--no-merged'

$RepoPath = $Config.Path
Set-Location $RepoPath

switch ($Sub) {
    'list' {
        $Cmd = "git branch"
        if ($All) { $Cmd += " -a" }
        if ($List) { $Cmd += " -l" }
        if ($Remote) { $Cmd += " -r" }
        if ($Contains) { $Cmd += " --contains $Contains" }
        if ($Merged) { $Cmd += " --merged" }
        if ($NoMerged) { $Cmd += " --no-merged" }
        $Out = & $Cmd
        $Out | Format-ToolOutput -Format $Format
    }
    'create' {
        if (-not $Name) { Write-Host "$($C.Crit)[ERROR] Usage: branch create <name> [start-point]$($C.Reset)"; return }
        if (-not $Force -and -not $PSCmdlet.ShouldProcess("Git repository", "Create branch '$Name'")) { return }
        $Cmd = "git branch $Name"
        if ($StartPoint) { $Cmd += " $StartPoint" }
        & $Cmd
    }
    'delete' {
        if (-not $Name) { Write-Host "$($C.Crit)[ERROR] Usage: branch delete <name> [-d|-D]$($C.Reset)"; return }
        if (-not $Force -and -not $PSCmdlet.ShouldProcess("Git repository", "Delete branch '$Name'")) { return }
        $Cmd = "git branch @(if($ForceDelete){'-D'}else{'-d'}) $Name"
        & $Cmd
    }
    'rename' {
        if (-not $Name -or -not $StartPoint) { Write-Host "$($C.Crit)[ERROR] Usage: branch rename <old> <new>$($C.Reset)"; return }
        if (-not $Force -and -not $PSCmdlet.ShouldProcess("Git repository", "Rename branch '$Name' to '$StartPoint'")) { return }
        & git branch -m $Name $StartPoint
    }
    'switch' {
        if (-not $Name) { Write-Host "$($C.Crit)[ERROR] Usage: branch switch <name>$($C.Reset)"; return }
        if (-not $Force -and -not $PSCmdlet.ShouldProcess("Git repository", "Switch to branch '$Name'")) { return }
        & git switch $Name
    }
    default { Write-Host "$($C.Crit)[ERROR] Usage: branch [list|create|delete|rename|switch] ...$($C.Reset)" }
}