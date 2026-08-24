# Type: Action
# Description: Shows the working tree status.
param($Config, [array]$Arguments)
$C = Get-ToolkitColors
$ArgsOnly = @($Arguments | Where-Object { $_ -notin @("-Force", "-f", "-json", "-csv", "-raw", "-table", "-h", "-?") })
$Format = "table"
if ($Arguments -contains '-json') { $Format = 'json' } elseif ($Arguments -contains '-csv') { $Format = 'csv' } elseif ($Arguments -contains '-raw') { $Format = 'raw' }
$Short = $Arguments -contains '-s' -or $Arguments -contains '--short'
$RepoPath = $Config.Path

Set-Location $RepoPath
$Cmd = "git status"
if ($Short) { $Cmd += " --short" }
$Out = & $Cmd
$Out | Format-ToolOutput -Format $Format
