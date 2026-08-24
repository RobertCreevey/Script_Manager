# Type: Action
# Description: Shows various types of Git objects (commits, tags, trees, blobs).
[CmdletBinding()]
param($Config, [array]$Arguments)
$Parsed = Get-ActionArguments -Arguments $Arguments
$ArgsOnly = $Parsed.ArgsOnly
$Format = $Parsed.Format
$Force = $Parsed.Switches.Force
$C = Get-ToolkitColors

$Object = $ArgsOnly[0]
$Stat = $ArgsOnly -contains '--stat'
$Patch = $ArgsOnly -contains '-p' -or $ArgsOnly -contains '--patch'
$NameOnly = $ArgsOnly -contains '--name-only'
$NameStatus = $ArgsOnly -contains '--name-status'
$Oneline = $ArgsOnly -contains '--oneline'

if (-not $Object) {
    Write-Host "$($C.Warn)[ERROR] Usage: show <object> [--stat] [-p] [--name-only] [--name-status] [--oneline]$($C.Reset)"
    return
}

$RepoPath = $Config.Path
Set-Location $RepoPath

$Cmd = "git show"
if ($Stat) { $Cmd += " --stat" }
if ($Patch) { $Cmd += " -p" }
if ($NameOnly) { $Cmd += " --name-only" }
if ($NameStatus) { $Cmd += " --name-status" }
if ($Oneline) { $Cmd += " --oneline" }
$Cmd += " $Object"

$Out = & $Cmd
$Out | Format-ToolOutput -Format $Format