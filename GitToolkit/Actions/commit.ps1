# Type: Action
# Description: Records changes to the repository.
param($Config, [array]$Arguments)
$C = Get-ToolkitColors
$ArgsOnly = @($Arguments | Where-Object { $_ -notin @("-Force", "-f", "-json", "-csv", "-raw", "-table", "-h", "-?") })
$Format = "table"
if ($Arguments -contains '-json') { $Format = 'json' } elseif ($Arguments -contains '-csv') { $Format = 'csv' } elseif ($Arguments -contains '-raw') { $Format = 'raw' }
$Message = $null
$Amend = $Arguments -contains '--amend'
$All = $Arguments -contains '-a' -or $Arguments -contains '--all'
$Signoff = $Arguments -contains '-s' -or $Arguments -contains '--signoff'

for ($i = 0; $i -lt $Arguments.Count; $i++) {
    if ($Arguments[$i] -eq '-m' -or $Arguments[$i] -eq '--message') {
        if ($i+1 -lt $Arguments.Count) { $Message = $Arguments[$i+1]; $i++ }
    }
}

if (-not $Message -and -not $Amend) {
    Write-Host "$($C.Warn)[ERROR] Usage: commit -m <message> [--amend] [-a] [-s]$($C.Reset)"
    return
}

$RepoPath = $Config.Path
Set-Location $RepoPath

$Cmd = "git commit"
if ($Message) { $Cmd += " -m `"$Message`"" }
if ($Amend) { $Cmd += " --amend" }
if ($All) { $Cmd += " -a" }
if ($Signoff) { $Cmd += " -s" }

& $Cmd
[PSCustomObject]@{ Action='commit'; Status='Completed' } | Format-ToolOutput -Format $Format
