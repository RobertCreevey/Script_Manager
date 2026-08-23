# Type: Action
# Description: Smart interactive notification: shows a popup with action buttons, each firing a different chain based on the user's choice (buttons and mapping as args, or a preset name).
param($Config, [array]$Arguments)
$C = if ($global:ToolColors) { $global:ToolColors } else { [PSCustomObject]@{} }

# Built-in presets for common scenarios (message, title, buttons, chainMap)
$Presets = @{
    diskfull = @{
        Message = "Target disk is critically low. Choose a remediation:"
        Title   = "Disk Space Alert"
        Buttons = "Cleanup,RestartSvc,Ignore"
        Map     = "Cleanup:cleanup;RestartSvc:restartsvc;Ignore:noop"
    }
    offline  = @{
        Message = "Target is offline. How do you want to proceed?"
        Title   = "Connectivity Alert"
        Buttons = "Retry,WOL,Abort"
        Map     = "Retry:noop;WOL:wol;Abort:noop"
    }
}

$PresetName = if ($Arguments[0] -and $Presets[$Arguments[0]]) { $Arguments[0] } else { $null }

if ($PresetName) {
    $P = $Presets[$PresetName]
    $ActionArgs = @($P.Message, $P.Title, $P.Buttons, $P.Map)
} else {
    # Free form: alert <message> <title> <buttons> <chainMap>
    $Message = if ($Arguments[0]) { $Arguments[0] } else { "Choose an action" }
    $Title   = if ($Arguments[1]) { $Arguments[1] } else { "SSHToolkit" }
    $Buttons = if ($Arguments[2]) { $Arguments[2] } else { "OK,Cancel" }
    $Map     = if ($Arguments[3]) { $Arguments[3] } else { "" }
    $ActionArgs = @($Message, $Title, $Buttons, $Map)
}

Write-Host "$($C.Info)[ALERT]$($C.Reset) Raising interactive alert..." -ForegroundColor Cyan
& "$global:SharedToolkitPath\Actions\ask.ps1" -Config $Config -Arguments $ActionArgs
