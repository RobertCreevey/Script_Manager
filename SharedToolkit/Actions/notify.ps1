# Type: Action
# Description: Sends a unified severity-aware notification (toast + beep, speech for critical) and logs it to the event system.
param($Config, [array]$Arguments)
$Severities = @('info', 'warn', 'error', 'critical')
if ($Arguments[0] -and $Arguments[0] -in $Severities) {
    $Severity = $Arguments[0]
    $Title = if ($Arguments[1]) { $Arguments[1] } else { "SSHToolkit" }
    $Message = if ($Arguments[2]) { ($Arguments[2..($Arguments.Length - 1)] -join " ") } else { "" }
} else {
    $Severity = "info"
    $Title = if ($Arguments[0]) { $Arguments[0] } else { "SSHToolkit" }
    $Message = if ($Arguments[1]) { ($Arguments[1..($Arguments.Length - 1)] -join " ") } else { "" }
}
Invoke-ToolNotify -Title $Title -Message $Message -Severity $Severity -Config $Config
