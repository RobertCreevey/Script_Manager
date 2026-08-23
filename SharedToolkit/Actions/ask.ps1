# Type: Action
# Description: Shows an interactive local popup with configurable buttons and returns the choice; optionally fires a chain based on the button pressed (map as button1:chain1;button2:chain2).
param($Config, [array]$Arguments)
$C = if ($global:ToolColors) { $global:ToolColors } else { [PSCustomObject]@{} }

$Message = if ($Arguments[0]) { $Arguments[0] } else { "Choose an action" }
$Title = if ($Arguments[1]) { $Arguments[1] } else { "SSHToolkit" }

# Buttons: comma or semicolon separated labels. Defaults to Yes/No.
$ButtonSpec = if ($Arguments[2]) { $Arguments[2] } else { "Yes,No" }
$Buttons = $ButtonSpec -split '[,;]' | ForEach-Object { $_.Trim() } | Where-Object { $_ }

# Optional chain map: "Yes:chainNameA;No:chainNameB"
$ChainMap = @{}
if ($Arguments[3]) {
    ($Arguments[3] -split ';') | ForEach-Object {
        $kv = $_ -split ':', 2
        if ($kv.Count -eq 2) { $ChainMap[$kv[0].Trim()] = $kv[1].Trim() }
    }
}

[int]$ButtonType = 4   # 0=OK, 1=OK/Cancel, 2=Abort/Retry/Ignore, 3=Yes/No/Cancel, 4=Yes/No, 5=Retry/Cancel
switch ($Buttons.Count) {
    1 { $ButtonType = 0 }
    2 { $ButtonType = 4 }
    3 { $ButtonType = 3 }
    default { $ButtonType = 4 }
}

$ws = New-Object -ComObject WScript.Shell
$Result = $ws.Popup($Message, 0, "$Title ($($Buttons -join ' / '))", $ButtonType + 32)

# Popup returns: 1=OK, 2=Cancel, 3=Abort, 4=Retry, 5=Ignore, 6=Yes, 7=No
$Choice = switch ($Result) {
    1 { $Buttons[0] }
    6 { $Buttons[0] }
    7 { if ($Buttons[1]) { $Buttons[1] } else { $Buttons[0] } }
    2 { "Cancel" }
    3 { "Abort" }
    4 { "Retry" }
    5 { "Ignore" }
    default { "Dismissed" }
}

Write-Host "$($C.Info)[ASK]$($C.Reset) '$Title' → $Choice" -ForegroundColor Cyan
Invoke-ToolEvent -Name "Ask" -Data "$Title : $Choice" -Config $Config

if ($ChainMap -and $ChainMap[$Choice]) {
    $TargetChain = $ChainMap[$Choice]
    Write-Host "$($C.Param)→ firing chain '$TargetChain'$($C.Reset)" -ForegroundColor $C.Param
    try { Invoke-UniversalToolkitRouter -Action "chain" -ForwardedArgs @("run", $TargetChain) } catch {
        Invoke-ToolError -Message "Chain '$TargetChain' failed: $_" -Severity Error -Config $Config
    }
}
