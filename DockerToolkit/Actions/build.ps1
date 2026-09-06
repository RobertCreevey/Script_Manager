# Type: Action
# Description: Builds a Docker image from a Dockerfile.
[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]
param($Config, [array]$Arguments)
$Parsed = Get-ActionArguments -Arguments $Arguments
$ArgsOnly = $Parsed.ArgsOnly
$Format = $Parsed.Format
$Force = $Parsed.Switches.Force
$C = Get-ToolkitColors

$Path = $ArgsOnly[0]
$Tag = $ArgsOnly | Where-Object { $_ -match '^-t=' -or $_ -match '^--tag=' } | ForEach-Object { $_ -replace '^-t=', '' -replace '^--tag=', '' }
$File = $ArgsOnly | Where-Object { $_ -match '^-f=' -or $_ -match '^--file=' } | ForEach-Object { $_ -replace '^-f=', '' -replace '^--file=', '' }
$NoCache = $ArgsOnly -contains '--no-cache'
$Target = $ArgsOnly | Where-Object { $_ -match '^--target=' } | ForEach-Object { $_ -replace '^--target=', '' }
$BuildArg = $ArgsOnly | Where-Object { $_ -match '^--build-arg=' } | ForEach-Object { $_ -replace '^--build-arg=', '' }
$Platform = $ArgsOnly | Where-Object { $_ -match '^--platform=' } | ForEach-Object { $_ -replace '^--platform=', '' }

if (-not $Path) {
    Write-Host "$($C.Crit)[ERROR] Usage: build <path> [-t name:tag] [-f Dockerfile] [--no-cache] [--target stage] [--build-arg KEY=VAL] [--platform PLATFORM]$($C.Reset)"
    return
}

$DockerHost = if ($Config.Host) { "-H $($Config.Host)" } else { "" }
$DockerContext = if ($Config.Context -and $Config.Context -ne 'default') { "--context $($Config.Context)" } else { "" }
$BaseCmd = "docker $DockerHost $DockerContext"

$Args = @("build")
if ($NoCache) { $Args += "--no-cache" }
if ($Tag) { $Args += @("-t", $Tag) }
if ($File) { $Args += @("-f", $File) }
if ($Target) { $Args += @("--target", $Target) }
if ($BuildArg) { $Args += @("--build-arg", $BuildArg) }
if ($Platform) { $Args += @("--platform", $Platform) }
$Args += $Path

$Cmd = "$BaseCmd $($Args -join ' ')"

if (-not $Force -and -not $PSCmdlet.ShouldProcess("Docker build", "Build image from $Path")) { return }
& powershell -NoProfile -Command $Cmd