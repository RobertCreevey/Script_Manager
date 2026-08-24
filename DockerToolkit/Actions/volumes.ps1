# Type: Action
# Description: Manages Docker volumes (list, create, remove, prune, inspect).
[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]
param($Config, [array]$Arguments)
$Parsed = Get-ActionArguments -Arguments $Arguments
$ArgsOnly = $Parsed.ArgsOnly
$Format = $Parsed.Format
$Force = $Parsed.Switches.Force
$C = Get-ToolkitColors

$Sub = if ($ArgsOnly[0]) { $ArgsOnly[0] } else { 'ls' }
$Name = $ArgsOnly[1]

$DockerHost = if ($Config.Host) { "-H $($Config.Host)" } else { "" }
$DockerContext = if ($Config.Context -and $Config.Context -ne 'default') { "--context $($Config.Context)" } else { "" }
$BaseCmd = "docker $DockerHost $DockerContext"

switch ($Sub) {
    'ls' {
        $Filter = if ($Name) { "--filter name=$Name" } else { "" }
        $Cmd = "$BaseCmd volume ls $Filter --format '{{.Name}}|{{.Driver}}|{{.Mountpoint}}|{{.Scope}}'"
        $Out = & powershell -NoProfile -Command $Cmd
        $Results = $Out | ForEach-Object {
            $Parts = $_ -split '\|'
            [PSCustomObject]@{ Name=$Parts[0]; Driver=$Parts[1]; Mountpoint=$Parts[2]; Scope=$Parts[3] }
        }
        $Results | Format-ToolOutput -Format $Format
    }
    'create' {
        if (-not $Name) { Write-Host "$($C.Warn)[ERROR] Usage: volumes create <name> [--driver <driver>]$($C.Reset)"; return }
        $Driver = $ArgsOnly | Where-Object { $_ -match '^--driver=' } | ForEach-Object { $_ -replace '--driver=', '' }
        if (-not $Driver) { $Driver = 'local' }
        if (-not $Force -and -not $PSCmdlet.ShouldProcess("Docker volume", "Create volume '$Name'")) { return }
        & $BaseCmd volume create --driver $Driver $Name
    }
    'rm' {
        if (-not $Name) { Write-Host "$($C.Warn)[ERROR] Usage: volumes rm <name> [-f]$($C.Reset)"; return }
        if (-not $Force -and -not $PSCmdlet.ShouldProcess("Docker volume", "Remove volume '$Name'")) { return }
        & $BaseCmd volume rm $Name
    }
    'prune' {
        if (-not $Force -and -not $PSCmdlet.ShouldProcess("Docker volumes", "Prune unused volumes")) { return }
        & $BaseCmd volume prune -f
    }
    'inspect' {
        if (-not $Name) { Write-Host "$($C.Warn)[ERROR] Usage: volumes inspect <name> [-json]$($C.Reset)"; return }
        $Out = & $BaseCmd volume inspect $Name | ConvertFrom-Json
        if ($Format -eq 'json') { $Out | ConvertTo-Json -Depth 5 } else { $Out | Format-List * }
    }
    default { Write-Host "$($C.Warn)[ERROR] Usage: volumes [ls|create|rm|prune|inspect] ...$($C.Reset)" }
}