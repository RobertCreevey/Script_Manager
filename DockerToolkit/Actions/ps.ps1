# Type: Action
# Description: Lists and manages containers (ps, start, stop, restart, rm, inspect).
param($Config, [array]$Arguments)
$C = Get-ToolkitColors
$ArgsOnly = @($Arguments | Where-Object { $_ -notin @("-Force", "-f", "-json", "-csv", "-raw", "-table", "-a", "--all") })
$Format = "table"
if ($Arguments -contains '-json') { $Format = 'json' } elseif ($Arguments -contains '-csv') { $Format = 'csv' } elseif ($Arguments -contains '-raw') { $Format = 'raw' }
$All = $Arguments -contains '-a' -or $Arguments -contains '--all'
$Sub = if ($ArgsOnly[0]) { $ArgsOnly[0] } else { 'ps' }
$Target = $ArgsOnly[1]
$DockerHost = if ($Config.Host) { "-H $($Config.Host)" } else { "" }
$DockerContext = if ($Config.Context -and $Config.Context -ne 'default') { "--context $($Config.Context)" } else { "" }

$BaseCmd = "docker $DockerHost $DockerContext"

switch ($Sub) {
    'ps' {
        $Filter = if ($Target) { "--filter name=$Target" } else { "" }
        $AllFlag = if ($All) { '-a' } else { '' }
        $Cmd = "$BaseCmd ps $AllFlag $Filter --format '{{.ID}}|{{.Names}}|{{.Image}}|{{.Status}}|{{.Ports}}|{{.CreatedAt}}'"
        $Out = & powershell -NoProfile -Command $Cmd
        $Results = $Out | ForEach-Object {
            $Parts = $_ -split '\|'
            [PSCustomObject]@{ ID=$Parts[0]; Name=$Parts[1]; Image=$Parts[2]; Status=$Parts[3]; Ports=$Parts[4]; Created=$Parts[5] }
        }
        $Results | Format-ToolOutput -Format $Format
    }
    'start' {
        if (-not $Target) { Write-Host "$($C.Crit)[ERROR] Usage: ps start <name|id>$($C.Reset)" ; return }
        if (-not (Request-ToolkitConfirmation -Verb "start container" -Command "docker start $Target" -Config $Config -Arguments $Arguments)) { return }
        & $BaseCmd start $Target
    }
    'stop' {
        if (-not $Target) { Write-Host "$($C.Crit)[ERROR] Usage: ps stop <name|id> [timeout]$($C.Reset)" ; return }
        $Timeout = if ($ArgsOnly[2]) { $ArgsOnly[2] } else { 10 }
        if (-not (Request-ToolkitConfirmation -Verb "stop container" -Command "docker stop $Target" -Config $Config -Arguments $Arguments)) { return }
        & $BaseCmd stop -t $Timeout $Target
    }
    'restart' {
        if (-not $Target) { Write-Host "$($C.Crit)[ERROR] Usage: ps restart <name|id> [timeout]$($C.Reset)" ; return }
        $Timeout = if ($ArgsOnly[2]) { $ArgsOnly[2] } else { 10 }
        if (-not (Request-ToolkitConfirmation -Verb "restart container" -Command "docker restart $Target" -Config $Config -Arguments $Arguments)) { return }
        & $BaseCmd restart -t $Timeout $Target
    }
    'rm' {
        if (-not $Target) { Write-Host "$($C.Crit)[ERROR] Usage: ps rm <name|id> [-f]$($C.Reset)" ; return }
        $Force = $Arguments -contains '-f'
        if (-not (Request-ToolkitConfirmation -Verb "remove container" -Command "docker rm $Target" -Config $Config -Arguments $Arguments)) { return }
        & $BaseCmd rm @(if($Force){"-f"}) $Target
    }
    'logs' {
        if (-not $Target) { Write-Host "$($C.Crit)[ERROR] Usage: ps logs <name|id> [-f] [--tail N]$($C.Reset)" ; return }
        $Follow = $Arguments -contains '-f'
        $Tail = $Arguments | Where-Object { $_ -match '^--tail=\d+$' } | ForEach-Object { $_ -replace '--tail=', '' }
        if (-not $Tail) { $Tail = "100" }
        & $BaseCmd logs @(if($Follow){"-f"}) --tail $Tail $Target
    }
    'exec' {
        if (-not $Target -or $ArgsOnly.Count -lt 2) { Write-Host "$($C.Crit)[ERROR] Usage: ps exec <name|id> <cmd> [args...]$($C.Reset)" ; return }
        $Cmd = $ArgsOnly[1..($ArgsOnly.Count-1)] -join ' '
        & $BaseCmd exec -it $Target $Cmd
    }
    'inspect' {
        if (-not $Target) { Write-Host "$($C.Crit)[ERROR] Usage: ps inspect <name|id> [-json]$($C.Reset)" ; return }
        $Out = & $BaseCmd inspect $Target | ConvertFrom-Json
        if ($Format -eq 'json') { $Out | ConvertTo-Json -Depth 5 } else { $Out | Format-List * }
    }
    'stats' {
        $Target = if ($Target) { $Target } else { "" }
        & $BaseCmd stats --no-stream $Target
    }
    default { Write-Host "$($C.Crit)[ERROR] Usage: ps [ps|start|stop|restart|rm|logs|exec|inspect|stats] ...$($C.Reset)" }
}

