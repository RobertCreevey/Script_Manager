# Type: Action
# Description: Shows real-time resource usage statistics for containers (CPU, memory, network, block I/O).
[CmdletBinding()]
param($Config, [array]$Arguments)
$Parsed = Get-ActionArguments -Arguments $Arguments
$ArgsOnly = $Parsed.ArgsOnly
$Format = $Parsed.Format
$Force = $Parsed.Switches.Force
$C = Get-ToolkitColors

$Container = $ArgsOnly[0]
$NoStream = $ArgsOnly -contains '--no-stream'
$FormatOpt = $ArgsOnly | Where-Object { $_ -match '^--format=' } | ForEach-Object { $_ -replace '--format=', '' }

$DockerHost = if ($Config.Host) { "-H $($Config.Host)" } else { "" }
$DockerContext = if ($Config.Context -and $Config.Context -ne 'default') { "--context $($Config.Context)" } else { "" }
$BaseCmd = "docker $DockerHost $DockerContext"

if ($NoStream -and -not $FormatOpt) {
    # Default table format for non-streaming
    $FormatOpt = 'table {{.Container}}\t{{.CPUPerc}}\t{{.MemPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}\t{{.PIDs}}'
}

$Cmd = "$BaseCmd stats @(if($NoStream){'--no-stream'}) @(if($FormatOpt){'--format ' + $FormatOpt}) $Container"
& powershell -NoProfile -Command $Cmd