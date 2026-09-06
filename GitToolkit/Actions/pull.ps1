# Type: Action
# Description: Fetches from and integrates with another repository or a local branch.
param($Config, [array]$Arguments)
$C = Get-ToolkitColors
$ArgsOnly = @($Arguments | Where-Object { $_ -notin @("-Force", "-f", "-json", "-csv", "-raw", "-table", "-h", "-?") })
$Format = "table"
if ($Arguments -contains '-json') { $Format = 'json' } elseif ($Arguments -contains '-csv') { $Format = 'csv' } elseif ($Arguments -contains '-raw') { $Format = 'raw' }
$Remote = if ($ArgsOnly[0]) { $ArgsOnly[0] } else { $Config.Remote }
$Branch = if ($ArgsOnly[1]) { $ArgsOnly[1] } else { "" }
$Rebase = $Arguments -contains '--rebase'

if (-not $Remote) { Write-Host "$($C.Crit)[ERROR] Usage: pull [remote] [branch] [--rebase]$($C.Reset)"; return }

$RepoPath = $Config.Path
Set-Location $RepoPath

$Cmd = "git pull $Remote"
if ($Branch) { $Cmd += " $Branch" }
if ($Rebase) { $Cmd += " --rebase" }

& $Cmd
[PSCustomObject]@{ Action='pull'; Remote=$Remote; Branch=$Branch; Status='Completed' } | Format-ToolOutput -Format $Format
