# Type: Action
# Description: Pulls a Docker image from a registry.
[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Low')]
param($Config, [array]$Arguments)
$Parsed = Get-ActionArguments -Arguments $Arguments
$ArgsOnly = $Parsed.ArgsOnly
$Format = $Parsed.Format
$Force = $Parsed.Switches.Force
$C = Get-ToolkitColors

$Image = $ArgsOnly[0]
$AllTags = $ArgsOnly -contains '-a' -or $ArgsOnly -contains '--all-tags'
$Platform = $ArgsOnly | Where-Object { $_ -match '^--platform=' } | ForEach-Object { $_ -replace '^--platform=', '' }

if (-not $Image) {
    Write-Host "$($C.Warn)[ERROR] Usage: pull <image>[:tag] [-a] [--platform PLATFORM]$($C.Reset)"
    return
}

$DockerHost = if ($Config.Host) { "-H $($Config.Host)" } else { "" }
$DockerContext = if ($Config.Context -and $Config.Context -ne 'default') { "--context $($Config.Context)" } else { "" }
$BaseCmd = "docker $DockerHost $DockerContext"

$Args = @("pull")
if ($AllTags) { $Args += "-a" }
if ($Platform) { $Args += @("--platform", $Platform) }
$Args += $Image

$Cmd = "$BaseCmd $($Args -join ' ')"

if (-not $Force -and -not $PSCmdlet.ShouldProcess("Docker registry", "Pull image $Image")) { return }
& powershell -NoProfile -Command $Cmd