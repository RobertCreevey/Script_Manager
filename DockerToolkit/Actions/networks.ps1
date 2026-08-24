# Type: Action
# Description: Manages Docker networks (list, create, connect, disconnect, remove, prune, inspect).
[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]
param($Config, [array]$Arguments)
$Parsed = Get-ActionArguments -Arguments $Arguments
$ArgsOnly = $Parsed.ArgsOnly
$Format = $Parsed.Format
$Force = $Parsed.Switches.Force
$C = Get-ToolkitColors

$Sub = if ($ArgsOnly[0]) { $ArgsOnly[0] } else { 'ls' }
$Name = $ArgsOnly[1]
$Container = $ArgsOnly[2]

$DockerHost = if ($Config.Host) { "-H $($Config.Host)" } else { "" }
$DockerContext = if ($Config.Context -and $Config.Context -ne 'default') { "--context $($Config.Context)" } else { "" }
$BaseCmd = "docker $DockerHost $DockerContext"

switch ($Sub) {
    'ls' {
        $Filter = if ($Name) { "--filter name=$Name" } else { "" }
        $Cmd = "$BaseCmd network ls $Filter --format '{{.ID}}|{{.Name}}|{{.Driver}}|{{.Scope}}'"
        $Out = & powershell -NoProfile -Command $Cmd
        $Results = $Out | ForEach-Object {
            $Parts = $_ -split '\|'
            [PSCustomObject]@{ ID=$Parts[0]; Name=$Parts[1]; Driver=$Parts[2]; Scope=$Parts[3] }
        }
        $Results | Format-ToolOutput -Format $Format
    }
    'create' {
        if (-not $Name) { Write-Host "$($C.Warn)[ERROR] Usage: networks create <name> [--driver <driver>] [--subnet <cidr>] [--gateway <ip>]$($C.Reset)"; return }
        $Driver = $ArgsOnly | Where-Object { $_ -match '^--driver=' } | ForEach-Object { $_ -replace '--driver=', '' }
        if (-not $Driver) { $Driver = 'bridge' }
        $Subnet = $ArgsOnly | Where-Object { $_ -match '^--subnet=' } | ForEach-Object { $_ -replace '--subnet=', '' }
        $Gateway = $ArgsOnly | Where-Object { $_ -match '^--gateway=' } | ForEach-Object { $_ -replace '--gateway=', '' }
        $Args = @("create", "--driver", $Driver)
        if ($Subnet) { $Args += @("--subnet", $Subnet) }
        if ($Gateway) { $Args += @("--gateway", $Gateway) }
        $Args += $Name
        if (-not $Force -and -not $PSCmdlet.ShouldProcess("Docker network", "Create network '$Name'")) { return }
        & $BaseCmd $Args
    }
    'connect' {
        if (-not $Name -or -not $Container) { Write-Host "$($C.Warn)[ERROR] Usage: networks connect <network> <container>$($C.Reset)"; return }
        if (-not $Force -and -not $PSCmdlet.ShouldProcess("Docker network '$Name'", "Connect container '$Container'")) { return }
        & $BaseCmd network connect $Name $Container
    }
    'disconnect' {
        if (-not $Name -or -not $Container) { Write-Host "$($C.Warn)[ERROR] Usage: networks disconnect <network> <container>$($C.Reset)"; return }
        if (-not $Force -and -not $PSCmdlet.ShouldProcess("Docker network '$Name'", "Disconnect container '$Container'")) { return }
        & $BaseCmd network disconnect $Name $Container
    }
    'rm' {
        if (-not $Name) { Write-Host "$($C.Warn)[ERROR] Usage: networks rm <name> [-f]$($C.Reset)"; return }
        if (-not $Force -and -not $PSCmdlet.ShouldProcess("Docker network", "Remove network '$Name'")) { return }
        & $BaseCmd network rm $Name
    }
    'prune' {
        if (-not $Force -and -not $PSCmdlet.ShouldProcess("Docker networks", "Prune unused networks")) { return }
        & $BaseCmd network prune -f
    }
    'inspect' {
        if (-not $Name) { Write-Host "$($C.Warn)[ERROR] Usage: networks inspect <name> [-json]$($C.Reset)"; return }
        $Out = & $BaseCmd network inspect $Name | ConvertFrom-Json
        if ($Format -eq 'json') { $Out | ConvertTo-Json -Depth 5 } else { $Out | Format-List * }
    }
    default { Write-Host "$($C.Warn)[ERROR] Usage: networks [ls|create|connect|disconnect|rm|prune|inspect] ...$($C.Reset)" }
}