# Type: Action
# Description: Shows a Yes/No popup on target and returns the response to the SSH session.
param($Config, [array]$Arguments)
$C = Get-ToolkitColors
$ArgsOnly = @($Arguments | Where-Object { $_ -notin @("-Force", "-f", "-json", "-csv", "-raw", "-table", "-h", "-?") })
$Format = "table"
if ($Arguments -contains '-json') { $Format = 'json' } elseif ($Arguments -contains '-csv') { $Format = 'csv' } elseif ($Arguments -contains '-raw') { $Format = 'raw' }
$Question = if ($ArgsOnly[0]) { $ArgsOnly[0] } else { "Proceed?" }
$Title = if ($ArgsOnly[1]) { $ArgsOnly[1] } else { "Incoming Request" }
$Timeout = if ($ArgsOnly[2]) { [int]$ArgsOnly[2] } else { 60 }
$YesAction = if ($ArgsOnly[3]) { $ArgsOnly[3] } else { "" }
$NoAction = if ($ArgsOnly[4]) { $ArgsOnly[4] } else { "" }

if (-not (Request-ToolkitConfirmation -Verb "interactive popup" -Command "popup $Question" -Config $Config -Arguments $Arguments)) { return }

$IP = $Config.IP
$User = $Config.User
$Key = $Config.Key

Write-Host "[popup] Sending Yes/No prompt to target..." -ForegroundColor Cyan

# Get logged-in user
$LoggedInUserCmd = "ssh $User@$IP -i $Key `(Get-CimInstance Win32_ComputerSystem).UserName"
$LoggedInUser = & powershell -NoProfile -Command $LoggedInUserCmd

# Build response handler script
$ResponseScript = @"
`$ResponseFile = "C:\Users\Public\popup_response.txt"
if (Test-Path `$ResponseFile) { Remove-Item `$ResponseFile -Force }

`$ScriptContent = {
    `$wshell = New-Object -ComObject Wscript.Shell
    `$Response = `$wshell.Popup(`"$Question`", 0, `"$Title`", 4 + 32)
    `$Response | Out-File `$ResponseFile -Force
}

`$Encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes(`$ScriptContent.ToString()))
`$Action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -WindowStyle Hidden -EncodedCommand `$Encoded"
`$Principal = New-ScheduledTaskPrincipal -UserId "`$LoggedInUser" -LogonType Interactive
Register-ScheduledTask -TaskName "InteractivePopup" -Action `$Action -Principal `$Principal | Out-Null
Start-ScheduledTask -TaskName "InteractivePopup"
"@

$ResponseEncoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($ResponseScript))
$SSHCmd = "ssh -i `$Key $User@$IP powershell -NoProfile -WindowStyle Hidden -EncodedCommand $ResponseEncoded"
& powershell -NoProfile -Command $SSHCmd

Write-Host "[popup] Waiting for response (${Timeout}s timeout)..." -ForegroundColor Yellow
$Counter = 0
$Response = $null
while ($Counter -lt $Timeout -and -not $Response) {
    $CheckCmd = "ssh -i `$Key $User@$IP Test-Path C:\Users\Public\popup_response.txt"
    $Exists = & powershell -NoProfile -Command $CheckCmd
    if ($Exists) {
        $ReadCmd = "ssh -i `$Key $User@$IP Get-Content C:\Users\Public\popup_response.txt"
        $Response = & powershell -NoProfile -Command $ReadCmd
        $Response = $Response.Trim()
    } else {
        Start-Sleep -Seconds 1
        $Counter++
    }
}

# Cleanup
$CleanupCmd = "ssh -i `$Key $User@$IP `; if (Test-Path C:\Users\Public\popup_response.txt) { Remove-Item C:\Users\Public\popup_response.txt -Force } `; Unregister-ScheduledTask -TaskName 'InteractivePopup' -Confirm:`$false -ErrorAction SilentlyContinue"
& powershell -NoProfile -Command $CleanupCmd

$Result = switch ($Response) {
    '6' { 'Yes' }
    '7' { 'No' }
    default { 'Timeout' }
}

Write-Host "[popup] Response: $Result" -ForegroundColor (if ($Result -eq 'Yes') { 'Green' } elseif ($Result -eq 'No') { 'Red' } else { 'Yellow' })

# Execute follow-up action if provided
if ($Result -eq 'Yes' -and $YesAction) {
    Write-Host "[popup] Executing Yes action: $YesAction" -ForegroundColor Cyan
    Invoke-UniversalToolkitRouter -Action $YesAction -ForwardedArgs @()
} elseif ($Result -eq 'No' -and $NoAction) {
    Write-Host "[popup] Executing No action: $NoAction" -ForegroundColor Cyan
    Invoke-UniversalToolkitRouter -Action $NoAction -ForwardedArgs @()
}

[PSCustomObject]@{ Action='popup'; Question=$Question; Response=$Result; Status='Completed' } | Format-ToolOutput -Format $Format

