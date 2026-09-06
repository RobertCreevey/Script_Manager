# Type: Action
# Description: Force-plays a video file on the target's physical screen via Scheduled Task (bypasses Session 0 isolation).
[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]
param(
    $Config,
    [array]$Arguments,
    [ValidateSet('wmplayer', 'edge')]
    [string]$Player = 'wmplayer',
    [switch]$Fullscreen
)

$Parsed = Get-ActionArguments -Arguments $Arguments
$ArgsOnly = $Parsed.ArgsOnly
$Format = $Parsed.Format
$Force = $Parsed.Switches.Force

$C = Get-ToolkitColors

$Path = $ArgsOnly[0]
$Player = if ($ArgsOnly[1]) { $ArgsOnly[1] } else { 'wmplayer' }  # wmplayer or edge

if (-not $Path) {
    Write-Host "$($C.Crit)[ERROR] Usage: play <path> [wmplayer|edge] [-fs]$($C.Reset)"
    Write-Host "$($C.Str)  Path must be accessible by the logged-in user (use C:\Users\Public\...)$($C.Reset)"
    return
}

if (-not $Force) {
    if ($PSCmdlet.ShouldProcess("Target $($Config.IP)", "Force-play video '$Path'")) {
        if (-not (Request-ToolkitConfirmation -Verb "force-play video" -Command "play $Path" -Config $Config -Arguments $Arguments)) { return }
    } else {
        return
    }
}

$IP = $Config.IP
$User = $Config.User
$Key = $Config.Key
$FileName = Split-Path $Path -Leaf
$PublicPath = "C:\Users\Public\$FileName"

Write-Host "[play] Copying to Public folder for cross-user access..." -ForegroundColor Cyan

# Use Start-Process with argument array for safe execution (avoids injection)
$ScpArgs = @("-i", $Key, $Path, "${User}@${IP}:${PublicPath}")
$ScpProc = Start-Process -FilePath "scp" -ArgumentList $ScpArgs -NoNewWindow -Wait -PassThru
if ($ScpProc.ExitCode -ne 0) { Write-Host "[FAIL] SCP copy failed." -ForegroundColor Red; return }

Write-Host "[play] Launching on target via Scheduled Task..." -ForegroundColor Cyan

# Get logged-in user via SSH
$SshArgs = @("-i", $Key, "${User}@${IP}", "(Get-CimInstance Win32_ComputerSystem).UserName")
$SshProc = Start-Process -FilePath "ssh" -ArgumentList $SshArgs -NoNewWindow -Wait -PassThru -RedirectStandardOutput "loggedin.txt"
$LoggedInUser = (Get-Content "loggedin.txt" -ErrorAction SilentlyContinue).Trim()
if (-not $LoggedInUser) { Write-Host "[FAIL] Could not determine logged-in user." -ForegroundColor Red; return }
Remove-Item "loggedin.txt" -ErrorAction SilentlyContinue

if ($Player -eq 'edge') {
    $EdgePath = 'file:///C:/Users/Public/' + $FileName
    $ActionArg = "--start-fullscreen `"$EdgePath`""
    $Exe = "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe"
} else {
    $ActionArg = "`"$PublicPath`" /fullscreen"
    $Exe = "${env:ProgramFiles}\Windows Media Player\wmplayer.exe"
}

$TaskScript = @"
`$Action = New-ScheduledTaskAction -Execute `"$Exe`" -Argument $ActionArg
`$Principal = New-ScheduledTaskPrincipal -UserId `"$LoggedInUser`" -LogonType Interactive
Register-ScheduledTask -TaskName `"ForceVideo_$FileName`" -Action `$Action -Principal `$Principal | Out-Null
Start-ScheduledTask -TaskName `"ForceVideo_$FileName`"
Start-Sleep -Seconds 3
Unregister-ScheduledTask -TaskName `"ForceVideo_$FileName`" -Confirm:`$false
"@

$Encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($TaskScript))
$SshExecArgs = @("-i", $Key, "$User@$IP", "powershell", "-NoProfile", "-WindowStyle", "Hidden", "-EncodedCommand", $Encoded)
Start-Process -FilePath "ssh" -ArgumentList $SshExecArgs -NoNewWindow -Wait

Write-Host "[play] Cleaning up remote file..." -ForegroundColor Cyan
$CleanupArgs = @("-i", $Key, "$User@$IP", "Remove-Item", "`"$PublicPath`"", "-Force")
Start-Process -FilePath "ssh" -ArgumentList $CleanupArgs -NoNewWindow -Wait

[PSCustomObject]@{ Action='play'; File=$FileName; Player=$Player; Status='Completed' } | Format-ToolOutput -Format $Format

