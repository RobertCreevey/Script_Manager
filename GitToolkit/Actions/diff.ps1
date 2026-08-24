# Type: Action
# Description: Shows changes between commits, commit and working tree, etc.
param($Config, [array]$Arguments)
$C = if ($global:ToolColors) { $global:ToolColors } else { [PSCustomObject]@{}}
$ArgsOnly = @($Arguments | Where-Object { $_ -notin @("-Force", "-f", "-json", "-csv", "-raw", "-table", "-h", "-?") })
$Format = "table"
if ($Arguments -contains '-json') { $Format = 'json' } elseif ($Arguments -contains '-csv') { $Format = 'csv' } elseif ($Arguments -contains '-raw') { $Format = 'raw' }
$Cached = $Arguments -contains '--cached' -or $Arguments -contains '--staged'
$NameOnly = $Arguments -contains '--name-only'
$Stat = $Arguments -contains '--stat'
$Target = $ArgsOnly[0]

$RepoPath = $Config.Path
Set-Location $RepoPath

$Cmd = "git diff"
if ($Cached) { $Cmd += " --cached" }
if ($NameOnly) { $Cmd += " --name-only" }
if ($Stat) { $Cmd += " --stat" }
if ($Target) { $Cmd += " $Target" }

$Out = & $Cmd
$Out | Format-ToolOutput -Format $Format