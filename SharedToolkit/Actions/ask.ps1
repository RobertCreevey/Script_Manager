# Type: Action
# Description: Interactive choice prompt — shows a popup (GUI/console/injection) with configurable buttons and returns the chosen button label. It never fires actions itself; the caller decides what to do with the choice.
param($Config, [array]$Arguments)

$Message = if ($Arguments[0]) { $Arguments[0] } else { "Choose an action" }
$Title = if ($Arguments[1]) { $Arguments[1] } else { "SSHToolkit" }

$ButtonSpec = if ($Arguments[2]) { $Arguments[2] } else { "OK,Cancel" }
$Buttons = $ButtonSpec -split '[,;]' | ForEach-Object { $_.Trim() } | Where-Object { $_ }

$Answer = if ($Arguments[3]) { $Arguments[3] } else { $env:TOOLKIT_PROMPT_DEFAULT }

Invoke-ToolPrompt -Message $Message -Title $Title -Buttons $Buttons -Default ($Buttons[0]) -Answer $Answer
