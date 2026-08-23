# Type: Action
# Description: Smart interactive alert: shows a popup with action buttons, requires confirmation detailing exactly what will be done, then fires the chosen chain. Supports presets (diskfull, offline) or free-form args.
param($Config, [array]$Arguments)
$C = if ($global:ToolColors) { $global:ToolColors } else { [PSCustomObject]@{} }

$Presets = @{
    diskfull = @{
        Problem  = "Target disk is critically low"
        Title    = "Disk Space Alert"
        Buttons  = "Cleanup,RestartSvc,Ignore"
        Map      = @{ Cleanup = "cleanup"; RestartSvc = "restartsvc"; Ignore = "noop" }
    }
    offline  = @{
        Problem  = "Target is offline / unreachable"
        Title    = "Connectivity Alert"
        Buttons  = "Retry,WOL,Abort"
        Map      = @{ Retry = "noop"; WOL = "wol"; Abort = "noop" }
    }
}

$PresetName = if ($Arguments[0] -and $Presets[$Arguments[0]]) { $Arguments[0] } else { $null }

if ($PresetName) {
    $P = $Presets[$PresetName]
    $Problem = $P.Problem
    $Title = $P.Title
    $Buttons = $P.Buttons
    $Map = $P.Map
} else {
    $Problem = if ($Arguments[0]) { $Arguments[0] } else { "Choose an action" }
    $Title = if ($Arguments[1]) { $Arguments[1] } else { "SSHToolkit" }
    $Buttons = if ($Arguments[2]) { $Arguments[2] } else { "OK,Cancel" }
    $Map = @{}
    if ($Arguments[3]) {
        ($Arguments[3] -split ';') | ForEach-Object {
            $kv = $_ -split ':', 2
            if ($kv.Count -eq 2) { $Map[$kv[0].Trim()] = $kv[1].Trim() }
        }
    }
}

Write-Host "$($C.Info)[ALERT]$($C.Reset) Raising interactive alert..." -ForegroundColor Cyan
$Choice = & "$global:SharedToolkitPath\Actions\ask.ps1" -Config $Config -Arguments @($Problem, $Title, $Buttons)

if ($Map -and $Map[$Choice]) {
    $TargetChain = $Map[$Choice]
    $ChainFile = $null
    @("$global:SSHToolkitPath\Chains", "$global:SharedToolkitPath\Chains") | ForEach-Object {
        if (Test-Path "$_\$TargetChain.json") { $ChainFile = "$_\$TargetChain.json" }
    }
    if ($ChainFile) {
        $Preview = Format-ChainPreview $ChainFile
        $Ctx = if ($Config) { "$($Config.User)@$($Config.IP)" } else { "local" }
        $Confirmed = Invoke-ToolConfirm -Problem $Problem -WillDo ("Will run chain '$TargetChain':`n$Preview") -Target $Ctx -Dangerous
        if (-not $Confirmed) { Write-Host "$($C.Warn)Alert action cancelled by user.$($C.Reset)" -ForegroundColor Yellow; return }
    }
    Write-Host "$($C.Param)→ running chain '$TargetChain'$($C.Reset)"
    try { Invoke-UniversalToolkitRouter -Action "chain" -ForwardedArgs @("run", $TargetChain) } catch {
        Invoke-ToolError -Message "Alert chain '$TargetChain' failed: $_" -Severity Error -Config $Config
    }
} else {
    Write-Host "$($C.Info)[ALERT]$($C.Reset) No action chosen or no chain mapped for '$Choice'." -ForegroundColor Gray
}
