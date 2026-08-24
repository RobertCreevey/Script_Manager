# Type: Action
# Description: Shows author information for each line in a file.
[CmdletBinding()]
param($Config, [array]$Arguments)
$Parsed = Get-ActionArguments -Arguments $Arguments
$ArgsOnly = $Parsed.ArgsOnly
$Format = $Parsed.Format
$Force = $Parsed.Switches.Force
$C = Get-ToolkitColors

$File = $ArgsOnly[0]
$StartLine = $ArgsOnly | Where-Object { $_ -match '^-L=' -or $_ -match '^--line=' } | ForEach-Object { $_ -replace '^-L=', '' -replace '^--line=', '' }
$IgnoreWhitespace = $ArgsOnly -contains '-w' -or $ArgsOnly -contains '--ignore-whitespace'
$ShowEmail = $ArgsOnly -contains '-e' -or $ArgsOnly -contains '--show-email'
$Minimal = $ArgsOnly -contains '--minimal'

if (-not $File) {
    Write-Host "$($C.Warn)[ERROR] Usage: blame <file> [-L start,end] [-w] [-e] [--minimal]$($C.Reset)"
    return
}

$RepoPath = $Config.Path
Set-Location $RepoPath

$Cmd = "git blame"
if ($StartLine) { $Cmd += " -L $StartLine" }
if ($IgnoreWhitespace) { $Cmd += " -w" }
if ($ShowEmail) { $Cmd += " -e" }
if ($Minimal) { $Cmd += " --minimal" }
$Cmd += " $File"

$Out = & $Cmd
$Out | Format-ToolOutput -Format $Format