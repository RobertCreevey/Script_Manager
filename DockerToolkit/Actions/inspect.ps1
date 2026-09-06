# Type: Action
# Description: Displays detailed information on Docker objects (containers, images, volumes, networks).
[CmdletBinding()]
param($Config, [array]$Arguments)
$Parsed = Get-ActionArguments -Arguments $Arguments
$ArgsOnly = $Parsed.ArgsOnly
$Format = $Parsed.Format
$Force = $Parsed.Switches.Force
$C = Get-ToolkitColors

$Type = if ($ArgsOnly[0]) { $ArgsOnly[0] } else { 'container' }
$Name = $ArgsOnly[1]

if (-not $Name) {
    Write-Host "$($C.Crit)[ERROR] Usage: inspect <container|image|volume|network> <name> [-json]$($C.Reset)"
    return
}

$DockerHost = if ($Config.Host) { "-H $($Config.Host)" } else { "" }
$DockerContext = if ($Config.Context -and $Config.Context -ne 'default') { "--context $($Config.Context)" } else { "" }
$BaseCmd = "docker $DockerHost $DockerContext"

$Cmd = "$BaseCmd $Type inspect $Name"
$Out = & powershell -NoProfile -Command $Cmd | ConvertFrom-Json

if ($Format -eq 'json') {
    $Out | ConvertTo-Json -Depth 10
} else {
    $Out | Format-List *
}