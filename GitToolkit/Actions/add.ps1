# Type: Action
# Description: Stages file changes for commit.
[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Low')]
param($Config, [array]$Arguments)
$Parsed = Get-ActionArguments -Arguments $Arguments
$ArgsOnly = $Parsed.ArgsOnly
$Format = $Parsed.Format
$Force = $Parsed.Switches.Force
$C = Get-ToolkitColors

$Paths = @($ArgsOnly | Where-Object { $_ -notin @('-A', '--all', '-p', '--patch', '-u', '--update', '-i', '--interactive', '-n', '--dry-run') })
$All = $ArgsOnly -contains '-A' -or $ArgsOnly -contains '--all'
$Patch = $ArgsOnly -contains '-p' -or $ArgsOnly -contains '--patch'
$Update = $ArgsOnly -contains '-u' -or $ArgsOnly -contains '--update'
$Interactive = $ArgsOnly -contains '-i' -or $ArgsOnly -contains '--interactive'
$DryRun = $ArgsOnly -contains '-n' -or $ArgsOnly -contains '--dry-run'

$RepoPath = $Config.Path
Set-Location $RepoPath

if (-not $Paths.Count -and -not $All -and -not $Update) {
    Write-Host "$($C.Crit)[ERROR] Usage: add <path>... [-A] [-u] [-p] [-i] [-n]$($C.Reset)"
    return
}

if (-not $Force -and -not $PSCmdlet.ShouldProcess("Git repository", "Stage changes")) { return }

$Cmd = "git add"
if ($All) { $Cmd += " -A" }
elseif ($Update) { $Cmd += " -u" }
if ($Patch) { $Cmd += " -p" }
if ($Interactive) { $Cmd += " -i" }
if ($DryRun) { $Cmd += " -n" }
if ($Paths.Count) { $Cmd += " $($Paths -join ' ')" }

& $Cmd