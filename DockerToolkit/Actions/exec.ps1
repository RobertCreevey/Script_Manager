# Type: Action
# Description: Executes a command inside a running container.
[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]
param($Config, [array]$Arguments)
$Parsed = Get-ActionArguments -Arguments $Arguments
$ArgsOnly = $Parsed.ArgsOnly
$Format = $Parsed.Format
$Force = $Parsed.Switches.Force
$C = Get-ToolkitColors

$Container = $ArgsOnly[0]
$CmdLine = $ArgsOnly[1..($ArgsOnly.Count-1)] -join ' '
$Interactive = $ArgsOnly -contains '-it' -or $ArgsOnly -contains '-i' -or $ArgsOnly -contains '-t'
$Detach = $ArgsOnly -contains '-d' -or $ArgsOnly -contains '--detach'
$User = $ArgsOnly | Where-Object { $_ -match '^--user=' } | ForEach-Object { $_ -replace '--user=', '' }
$Env = $ArgsOnly | Where-Object { $_ -match '^--env=' } | ForEach-Object { $_ -replace '--env=', '' }
$Workdir = $ArgsOnly | Where-Object { $_ -match '^--workdir=' } | ForEach-Object { $_ -replace '--workdir=', '' }
$Privileged = $ArgsOnly -contains '--privileged'

if (-not $Container -or -not $CmdLine) {
    Write-Host "$($C.Crit)[ERROR] Usage: exec <container> <command> [args...] [-it] [-d] [--user USER] [--env KEY=VAL] [--workdir PATH] [--privileged]$($C.Reset)"
    return
}

$DockerHost = if ($Config.Host) { "-H $($Config.Host)" } else { "" }
$DockerContext = if ($Config.Context -and $Config.Context -ne 'default') { "--context $($Config.Context)" } else { "" }
$BaseCmd = "docker $DockerHost $DockerContext"

$Args = @("exec")
if ($Interactive) { $Args += "-it" }
if ($Detach) { $Args += "-d" }
if ($Privileged) { $Args += "--privileged" }
if ($User) { $Args += @("--user", $User) }
if ($Env) { $Args += @("--env", $Env) }
if ($Workdir) { $Args += @("--workdir", $Workdir) }
$Args += $Container
$Args += $CmdLine -split ' '

$Cmd = "$BaseCmd $($Args -join ' ')"

if (-not $Force -and -not $PSCmdlet.ShouldProcess("Container '$Container'", "Execute: $CmdLine")) { return }
& powershell -NoProfile -Command $Cmd