# Type: Action
# Description: Removes unused Docker resources (containers, images, volumes, networks, build cache).
[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='High')]
param($Config, [array]$Arguments)
$Parsed = Get-ActionArguments -Arguments $Arguments
$ArgsOnly = $Parsed.ArgsOnly
$Format = $Parsed.Format
$Force = $Parsed.Switches.Force
$C = Get-ToolkitColors

$All = $ArgsOnly -contains '-a' -or $ArgsOnly -contains '--all'
$Volumes = $ArgsOnly -contains '--volumes'
$Filter = $ArgsOnly | Where-Object { $_ -match '^--filter=' } | ForEach-Object { $_ -replace '--filter=', '' }

$DockerHost = if ($Config.Host) { "-H $($Config.Host)" } else { "" }
$DockerContext = if ($Config.Context -and $Config.Context -ne 'default') { "--context $($Config.Context)" } else { "" }
$BaseCmd = "docker $DockerHost $DockerContext"

# System prune (containers, networks, images, build cache)
$Cmd = "$BaseCmd system prune @(if($All){'-a'}) @(if($Volumes){'--volumes'}) @(if($Filter){'--filter ' + $Filter}) -f"
if (-not $Force -and -not $PSCmdlet.ShouldProcess("Docker system", "Prune unused resources (containers, images, networks, build cache)")) { return }
$Out = & powershell -NoProfile -Command $Cmd
Write-Host $Out

# Container prune
$Cmd = "$BaseCmd container prune @(if($Filter){'--filter ' + $Filter}) -f"
& powershell -NoProfile -Command $Cmd

# Image prune
$Cmd = "$BaseCmd image prune @(if($All){'-a'}) @(if($Filter){'--filter ' + $Filter}) -f"
& powershell -NoProfile -Command $Cmd

# Volume prune
$Cmd = "$BaseCmd volume prune @(if($Filter){'--filter ' + $Filter}) -f"
& powershell -NoProfile -Command $Cmd

# Network prune
$Cmd = "$BaseCmd network prune @(if($Filter){'--filter ' + $Filter}) -f"
& powershell -NoProfile -Command $Cmd

# Build cache prune
$Cmd = "$BaseCmd builder prune @(if($All){'-a'}) @(if($Filter){'--filter ' + $Filter}) -f"
& powershell -NoProfile -Command $Cmd

Write-Host "[OK] Prune completed" -ForegroundColor Green