# Type: Action
# Description: Manages Docker images (list, pull, push, build, tag, rmi, prune).
param($Config, [array]$Arguments)
$C = Get-ToolkitColors
$ArgsOnly = @($Arguments | Where-Object { $_ -notin @("-Force", "-f", "-json", "-csv", "-raw", "-table", "-a", "--all") })
$Format = "table"
if ($Arguments -contains '-json') { $Format = 'json' } elseif ($Arguments -contains '-csv') { $Format = 'csv' } elseif ($Arguments -contains '-raw') { $Format = 'raw' }
$All = $Arguments -contains '-a' -or $Arguments -contains '--all'
$Sub = if ($ArgsOnly[0]) { $ArgsOnly[0] } else { 'ls' }
$Target = $ArgsOnly[1]
$Tag = $ArgsOnly[2]
$DockerHost = if ($Config.Host) { "-H $($Config.Host)" } else { "" }
$DockerContext = if ($Config.Context -and $Config.Context -ne 'default') { "--context $($Config.Context)" } else { "" }
$Registry = $Config.Registry
$Namespace = $Config.Namespace

$BaseCmd = "docker $DockerHost $DockerContext"

switch ($Sub) {
    'ls' {
        $Filter = if ($Target) { "--filter reference=$Target" } else { "" }
        $Cmd = "$BaseCmd images @(if($All){"-a"}) $Filter --format '{{.Repository}}|{{.Tag}}|{{.ID}}|{{.CreatedSince}}|{{.Size}}'"
        $Out = & powershell -NoProfile -Command $Cmd
        $Results = $Out | ForEach-Object {
            $Parts = $_ -split '\|'
            [PSCustomObject]@{ Repository=$Parts[0]; Tag=$Parts[1]; ID=$Parts[2]; Created=$Parts[3]; Size=$Parts[4] }
        }
        $Results | Format-ToolOutput -Format $Format
    }
    'pull' {
        if (-not $Target) { Write-Host "$($C.Warn)[ERROR] Usage: images pull <image>[:tag]$($C.Reset)" ; return }
        & $BaseCmd pull $Target
    }
    'push' {
        if (-not $Target) { Write-Host "$($C.Warn)[ERROR] Usage: images push <image>[:tag]$($C.Reset)" ; return }
        if (-not (Request-ToolkitConfirmation -Verb "push image" -Command "docker push $Target" -Config $Config -Arguments $Arguments)) { return }
        & $BaseCmd push $Target
    }
    'build' {
        if (-not $Target) { Write-Host "$($C.Warn)[ERROR] Usage: images build <path> [-t name:tag] [--no-cache]$($C.Reset)" ; return }
        $NoCache = $Arguments -contains '--no-cache'
        $TagArg = if ($Tag) { "-t $Tag" } elseif ($Registry -and $Namespace) { "-t $Registry/$Namespace/$(Split-Path $Target -Leaf):latest" } else { "" }
        & $BaseCmd build @(if($NoCache){"--no-cache"}) $TagArg $Target
    }
    'tag' {
        if (-not $Target -or -not $Tag) { Write-Host "$($C.Warn)[ERROR] Usage: images tag <src> <dst>[:tag]$($C.Reset)" ; return }
        & $BaseCmd tag $Target $Tag
    }
    'rmi' {
        if (-not $Target) { Write-Host "$($C.Warn)[ERROR] Usage: images rmi <image>[:tag] [-f]$($C.Reset)" ; return }
        $Force = $Arguments -contains '-f'
        if (-not (Request-ToolkitConfirmation -Verb "remove image" -Command "docker rmi $Target" -Config $Config -Arguments $Arguments)) { return }
        & $BaseCmd rmi @(if($Force){"-f"}) $Target
    }
    'prune' {
        if (-not (Request-ToolkitConfirmation -Verb "prune unused images" -Command "docker image prune" -Config $Config -Arguments $Arguments)) { return }
        & $BaseCmd image prune @(if($All){"-a"}) -f
    }
    'history' {
        if (-not $Target) { Write-Host "$($C.Warn)[ERROR] Usage: images history <image>[:tag]$($C.Reset)" ; return }
        & $BaseCmd history $Target
    }
    default { Write-Host "$($C.Warn)[ERROR] Usage: images [ls|pull|push|build|tag|rmi|prune|history] ...$($C.Reset)" }
}

