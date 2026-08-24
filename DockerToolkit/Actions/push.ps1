# Type: Action
# Description: Pushes a Docker image to a registry.
[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]
param($Config, [array]$Arguments)
$Parsed = Get-ActionArguments -Arguments $Arguments
$ArgsOnly = $Parsed.ArgsOnly
$Format = $Parsed.Format
$Force = $Parsed.Switches.Force
$C = Get-ToolkitColors

$Image = $ArgsOnly[0]
$AllTags = $ArgsOnly -contains '-a' -or $ArgsOnly -contains '--all-tags'

if (-not $Image) {
    Write-Host "$($C.Warn)[ERROR] Usage: push <image>[:tag] [-a]$($C.Reset)"
    return
}

$DockerHost = if ($Config.Host) { "-H $($Config.Host)" } else { "" }
$DockerContext = if ($Config.Context -and $Config.Context -ne 'default') { "--context $($Config.Context)" } else { "" }
$BaseCmd = "docker $DockerHost $DockerContext"

$Args = @("push")
if ($AllTags) { $Args += "-a" }
$Args += $Image

$Cmd = "$BaseCmd $($Args -join ' ')"

if (-not $Force -and -not $PSCmdlet.ShouldProcess("Docker registry", "Push image $Image")) { return }
& powershell -NoProfile -Command $Cmd