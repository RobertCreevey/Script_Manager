# Type: Action
# Description: Manages Docker Compose projects (up, down, ps, logs, build, pull).
[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]
param($Config, [array]$Arguments)
$Parsed = Get-ActionArguments -Arguments $Arguments
$ArgsOnly = $Parsed.ArgsOnly
$Format = $Parsed.Format
$Force = $Parsed.Switches.Force
$C = Get-ToolkitColors

$Sub = if ($ArgsOnly[0]) { $ArgsOnly[0] } else { 'up' }
$Project = $Config.Project ?? ''
$File = $Config.File ?? ''
$Profile = $Config.Profile ?? ''

$BaseArgs = @()
if ($File) { $BaseArgs += @("-f", $File) }
if ($Project) { $BaseArgs += @("-p", $Project) }
if ($Profile) { $BaseArgs += @("--profile", $Profile) }

$DockerHost = if ($Config.Host) { "-H $($Config.Host)" } else { "" }
$DockerContext = if ($Config.Context -and $Config.Context -ne 'default') { "--context $($Config.Context)" } else { "" }
$BaseCmd = "docker $DockerHost $DockerContext compose $($BaseArgs -join ' ')"

switch ($Sub) {
    'up' {
        $Detach = $ArgsOnly -contains '-d' -or $ArgsOnly -contains '--detach'
        $Build = $ArgsOnly -contains '--build'
        $Cmd = "$BaseCmd up @(if($Detach){'-d'}) @(if($Build){'--build'})"
        if (-not $Force -and -not $PSCmdlet.ShouldProcess("Docker Compose project", "Start containers (up)")) { return }
        & powershell -NoProfile -Command $Cmd
    }
    'down' {
        $Volumes = $ArgsOnly -contains '-v' -or $ArgsOnly -contains '--volumes'
        $Rmi = $ArgsOnly -contains '--rmi'
        $Cmd = "$BaseCmd down @(if($Volumes){'-v'}) @(if($Rmi){'--rmi all'})"
        if (-not $Force -and -not $PSCmdlet.ShouldProcess("Docker Compose project", "Stop and remove containers (down)")) { return }
        & powershell -NoProfile -Command $Cmd
    }
    'ps' {
        $Cmd = "$BaseCmd ps --format '{{.Name}}|{{.Service}}|{{.Status}}|{{.Ports}}'"
        $Out = & powershell -NoProfile -Command $Cmd
        $Results = $Out | ForEach-Object {
            $Parts = $_ -split '\|'
            [PSCustomObject]@{ Name=$Parts[0]; Service=$Parts[1]; Status=$Parts[2]; Ports=$Parts[3] }
        }
        $Results | Format-ToolOutput -Format $Format
    }
    'logs' {
        $Service = $ArgsOnly[1]
        $Follow = $ArgsOnly -contains '-f' -or $ArgsOnly -contains '--follow'
        $Tail = $ArgsOnly | Where-Object { $_ -match '^--tail=' } | ForEach-Object { $_ -replace '--tail=', '' }
        if (-not $Tail) { $Tail = "100" }
        $Cmd = "$BaseCmd logs @(if($Follow){'-f'}) --tail $Tail $Service"
        & powershell -NoProfile -Command $Cmd
    }
    'build' {
        $NoCache = $ArgsOnly -contains '--no-cache'
        $Cmd = "$BaseCmd build @(if($NoCache){'--no-cache'})"
        if (-not $Force -and -not $PSCmdlet.ShouldProcess("Docker Compose project", "Build images")) { return }
        & powershell -NoProfile -Command $Cmd
    }
    'pull' {
        $Cmd = "$BaseCmd pull"
        if (-not $Force -and -not $PSCmdlet.ShouldProcess("Docker Compose project", "Pull images")) { return }
        & powershell -NoProfile -Command $Cmd
    }
    default { Write-Host "$($C.Warn)[ERROR] Usage: compose [up|down|ps|logs|build|pull] ...$($C.Reset)" }
}