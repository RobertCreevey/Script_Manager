# Type: Action
# Description: Manages Git configuration (get, set, list, unset).
[CmdletBinding()]
param($Config, [array]$Arguments)
$Parsed = Get-ActionArguments -Arguments $Arguments
$ArgsOnly = $Parsed.ArgsOnly
$Format = $Parsed.Format
$Force = $Parsed.Switches.Force
$C = Get-ToolkitColors

$Sub = if ($ArgsOnly[0]) { $ArgsOnly[0] } else { 'list' }
$Key = $ArgsOnly[1]
$Value = $ArgsOnly[2]
$Scope = if ($ArgsOnly -contains '--local') { 'local' } elseif ($ArgsOnly -contains '--global') { 'global' } elseif ($ArgsOnly -contains '--system') { 'system' } else { 'local' }
$Unset = $ArgsOnly -contains '--unset'
$ReplaceAll = $ArgsOnly -contains '--replace-all'
$GetRegexp = $ArgsOnly -contains '--get-regexp'

$RepoPath = $Config.Path
Set-Location $RepoPath

switch ($Sub) {
    'list' {
        $Cmd = "git config --list"
        if ($Scope -ne 'local') { $Cmd = "git config --$Scope --list" }
        $Out = & $Cmd
        $Out | Format-ToolOutput -Format $Format
    }
    'get' {
        if (-not $Key) { Write-Host "$($C.Warn)[ERROR] Usage: config get <key> [--local|--global|--system]$($C.Reset)"; return }
        $Cmd = "git config --get"
        if ($Scope -ne 'local') { $Cmd = "git config --$Scope --get" }
        $Cmd += " $Key"
        $Out = & $Cmd
        $Out | Format-ToolOutput -Format $Format
    }
    'set' {
        if (-not $Key -or -not $Value) { Write-Host "$($C.Warn)[ERROR] Usage: config set <key> <value> [--local|--global|--system]$($C.Reset)"; return }
        $Cmd = "git config"
        if ($Scope -ne 'local') { $Cmd = "git config --$Scope" }
        if ($Unset) { $Cmd += " --unset" }
        if ($ReplaceAll) { $Cmd += " --replace-all" }
        $Cmd += " $Key $Value"
        & $Cmd
    }
    'unset' {
        if (-not $Key) { Write-Host "$($C.Warn)[ERROR] Usage: config unset <key> [--local|--global|--system]$($C.Reset)"; return }
        $Cmd = "git config --unset"
        if ($Scope -ne 'local') { $Cmd = "git config --$Scope --unset" }
        $Cmd += " $Key"
        & $Cmd
    }
    default { Write-Host "$($C.Warn)[ERROR] Usage: config [list|get|set|unset] ...$($C.Reset)" }
}