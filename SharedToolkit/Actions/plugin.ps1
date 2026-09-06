<#
.SYNOPSIS
    Manage the SharedToolkit plugin system.

.DESCRIPTION
    Plugin lifecycle (list / load / unload / reload / info / new / run) is
    implemented once, in SharedToolkit's Invoke-PluginAction function (also
    exposed as the `plugin` alias in an interactive session).

    This file is a thin, router-facing wrapper so that `server1 plugin <args>`
    dispatches through that SAME implementation instead of a second, drift-prone
    copy. It simply translates the router dispatch convention
    (param($Config, [array]$Arguments)) onto Invoke-PluginAction's
    param($Action, $PluginName, $PluginArgs, $Force).

.PARAMETER Config
    Toolkit config object (forwarded for context; plugin ops are local-only).

.PARAMETER Arguments
    Positional args from the router:  [Action] [PluginName] [extra args...]
    e.g.  plugin new MyPlugin   |   plugin run MyPlugin --flag
#>
[CmdletBinding()]
param(
    $Config,
    [Parameter(ValueFromRemainingArguments)]
    [string[]]$Arguments
)

# Parse the SharedToolkit action convention: -Arguments carries [Action] [PluginName] [PluginArgs...]
$Action     = if ($Arguments)                        { $Arguments[0] } else { 'list' }
$PluginName = if ($Arguments -and $Arguments.Count -gt 1) { $Arguments[1] } else { $null }
$PluginArgs = if ($Arguments -and $Arguments.Count -gt 2) { $Arguments[2..] } else { @() }
$Force      = $Arguments -contains '-Force'

Invoke-PluginAction -Action $Action -PluginName $PluginName -PluginArgs $PluginArgs -Force:$Force
