# Type: Action
# Description: Updates remote refs along with associated objects.
param($Config, [array]$Arguments)
$C = Get-ToolkitColors
$ArgsOnly = @($Arguments | Where-Object { $_ -notin @("-Force", "-f", "-json", "-csv", "-raw", "-table", "-h", "-?") })
$Format = "table"
if ($Arguments -contains '-json') { $Format = 'json' } elseif ($Arguments -contains '-csv') { $Format = 'csv' } elseif ($Arguments -contains '-raw') { $Format = 'raw' }
$Remote = if ($ArgsOnly[0]) { $ArgsOnly[0] } else { $Config.Remote }
$Branch = if ($ArgsOnly[1]) { $ArgsOnly[1] } else { "" }
$Force = $Arguments -contains '-f' -or $Arguments -contains '--force'
$ForceWithLease = $Arguments -contains '--force-with-lease'
$Tags = $Arguments -contains '--tags'

if (-not $Remote) { Write-Host "$($C.Warn)[ERROR] Usage: push [remote] [branch] [-f|--force-with-lease] [--tags]$($C.Reset)"; return }

$RepoPath = $Config.Path
Set-Location $RepoPath

$Cmd = "git push $Remote"
if ($Branch) { $Cmd += " $Branch" }
if ($Force) { $Cmd += " --force" }
if ($ForceWithLease) { $Cmd += " --force-with-lease" }
if ($Tags) { $Cmd += " --tags" }

& $Cmd
[PSCustomObject]@{ Action='push'; Remote=$Remote; Branch=$Branch; Status='Completed' } | Format-ToolOutput -Format $Format
