# Type: Action
# Description: Fetches container logs with tail/follow/filter options.
[CmdletBinding()]
param($Config, [array]$Arguments)
$Parsed = Get-ActionArguments -Arguments $Arguments
$ArgsOnly = $Parsed.ArgsOnly
$Format = $Parsed.Format
$Force = $Parsed.Switches.Force
$C = Get-ToolkitColors

$Container = $ArgsOnly[0]
$Follow = $ArgsOnly -contains '-f' -or $ArgsOnly -contains '--follow'
$Tail = $ArgsOnly | Where-Object { $_ -match '^--tail=' } | ForEach-Object { $_ -replace '--tail=', '' }
if (-not $Tail) { $Tail = "100" }
$Since = $ArgsOnly | Where-Object { $_ -match '^--since=' } | ForEach-Object { $_ -replace '--since=', '' }
$Until = $ArgsOnly | Where-Object { $_ -match '^--until=' } | ForEach-Object { $_ -replace '--until=', '' }
$Timestamps = $ArgsOnly -contains '--timestamps'
$Details = $ArgsOnly -contains '--details'

if (-not $Container) {
    Write-Host "$($C.Warn)[ERROR] Usage: logs <container> [-f] [--tail N] [--since TIME] [--until TIME] [--timestamps] [--details]$($C.Reset)"
    return
}

$DockerHost = if ($Config.Host) { "-H $($Config.Host)" } else { "" }
$DockerContext = if ($Config.Context -and $Config.Context -ne 'default') { "--context $($Config.Context)" } else { "" }
$BaseCmd = "docker $DockerHost $DockerContext"

$Cmd = "$BaseCmd logs $Container @(if($Follow){'-f'}) --tail $Tail"
if ($Since) { $Cmd += " --since $Since" }
if ($Until) { $Cmd += " --until $Until" }
if ($Timestamps) { $Cmd += " --timestamps" }
if ($Details) { $Cmd += " --details" }

& powershell -NoProfile -Command $Cmd