# Type: Action
# Description: Shows commit logs.
param($Config, [array]$Arguments)
$C = Get-ToolkitColors
$ArgsOnly = @($Arguments | Where-Object { $_ -notin @("-Force", "-f", "-json", "-csv", "-raw", "-table", "-h", "-?") })
$Format = "table"
if ($Arguments -contains '-json') { $Format = 'json' } elseif ($Arguments -contains '-csv') { $Format = 'csv' } elseif ($Arguments -contains '-raw') { $Format = 'raw' }
$Oneline = $Arguments -contains '--oneline'
$Graph = $Arguments -contains '--graph'
$Author = $null
$Since = $null
$Until = $null
$Count = $null
$Grep = $null

for ($i = 0; $i -lt $Arguments.Count; $i++) {
    switch ($Arguments[$i]) {
        '--author' { if ($i+1 -lt $Arguments.Count) { $Author = $Arguments[$i+1]; $i++ } }
        '--since' { if ($i+1 -lt $Arguments.Count) { $Since = $Arguments[$i+1]; $i++ } }
        '--until' { if ($i+1 -lt $Arguments.Count) { $Until = $Arguments[$i+1]; $i++ } }
        '-n' { if ($i+1 -lt $Arguments.Count) { $Count = $Arguments[$i+1]; $i++ } }
        '--grep' { if ($i+1 -lt $Arguments.Count) { $Grep = $Arguments[$i+1]; $i++ } }
    }
}

$RepoPath = $Config.Path
Set-Location $RepoPath

$Cmd = "git log"
if ($Oneline) { $Cmd += " --oneline" }
if ($Graph) { $Cmd += " --graph --decorate" }
if ($Author) { $Cmd += " --author=`"$Author`"" }
if ($Since) { $Cmd += " --since=`"$Since`"" }
if ($Until) { $Cmd += " --until=`"$Until`"" }
if ($Count) { $Cmd += " -n $Count" }
if ($Grep) { $Cmd += " --grep=`"$Grep`"" }

$Out = & $Cmd
$Out | Format-ToolOutput -Format $Format
