# Type: Action
# Description: Shows Docker system information (version, disk usage, info, events).
[CmdletBinding()]
param($Config, [array]$Arguments)
$Parsed = Get-ActionArguments -Arguments $Arguments
$ArgsOnly = $Parsed.ArgsOnly
$Format = $Parsed.Format
$Force = $Parsed.Switches.Force
$C = Get-ToolkitColors

$Sub = if ($ArgsOnly[0]) { $ArgsOnly[0] } else { 'info' }

$DockerHost = if ($Config.Host) { "-H $($Config.Host)" } else { "" }
$DockerContext = if ($Config.Context -and $Config.Context -ne 'default') { "--context $($Config.Context)" } else { "" }
$BaseCmd = "docker $DockerHost $DockerContext"

switch ($Sub) {
    'info' {
        $Cmd = "$BaseCmd info --format '{{json .}}'"
        $Out = & powershell -NoProfile -Command $Cmd | ConvertFrom-Json
        if ($Format -eq 'json') { $Out | ConvertTo-Json -Depth 5 } else { $Out | Format-List * }
    }
    'version' {
        $Cmd = "$BaseCmd version --format '{{json .}}'"
        $Out = & powershell -NoProfile -Command $Cmd | ConvertFrom-Json
        if ($Format -eq 'json') { $Out | ConvertTo-Json -Depth 5 } else { $Out | Format-List * }
    }
    'df' {
        $Cmd = "$BaseCmd system df --format '{{.Type}}\t{{.Total}}\t{{.Active}}\t{{.Size}}\t{{.Reclaimable}}'"
        $Out = & powershell -NoProfile -Command $Cmd
        $Results = $Out | ForEach-Object {
            $Parts = $_ -split '\t'
            [PSCustomObject]@{ Type=$Parts[0]; Total=$Parts[1]; Active=$Parts[2]; Size=$Parts[3]; Reclaimable=$Parts[4] }
        }
        $Results | Format-ToolOutput -Format $Format
    }
    'events' {
        $Since = $ArgsOnly | Where-Object { $_ -match '^--since=' } | ForEach-Object { $_ -replace '^--since=', '' }
        $Until = $ArgsOnly | Where-Object { $_ -match '^--until=' } | ForEach-Object { $_ -replace '^--until=', '' }
        $Filter = $ArgsOnly | Where-Object { $_ -match '^--filter=' } | ForEach-Object { $_ -replace '^--filter=', '' }
        $Cmd = "$BaseCmd events @(if($Since){'--since ' + $Since}) @(if($Until){'--until ' + $Until}) @(if($Filter){'--filter ' + $Filter})"
        & powershell -NoProfile -Command $Cmd
    }
    default { Write-Host "$($C.Crit)[ERROR] Usage: system [info|version|df|events] ...$($C.Reset)" }
}