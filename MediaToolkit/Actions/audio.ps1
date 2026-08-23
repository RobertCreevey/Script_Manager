# Type: Action
# Description: Gets or sets the master audio volume (0-100) and mute state on the local machine.
param($Config, [array]$Arguments)
$Arguments = @($Arguments)
Add-Type -TypeDefinition @'
using System.Runtime.InteropServices;
public class Audio {
    [DllImport("user32.dll")] public static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, int dwExtraInfo);
    public const byte VK_VOLUME_MUTE = 0xAD; public const byte VK_VOLUME_DOWN = 0xAE; public const byte VK_VOLUME_UP = 0xAF;
    public const uint KEYEVENTF_KEYDOWN = 0x0000; public const uint KEYEVENTF_KEYUP = 0x0002;
}
'@ -ErrorAction SilentlyContinue
$C = if ($global:ToolColors) { $global:ToolColors } else { [PSCustomObject]@{}}
if ($Arguments.Count -eq 0) {
    try {
        $Snd = New-Object -ComObject WScript.Shell
        Write-Host "[audio] Use: audio <0-100> | audio mute | audio unmute | audio toggle" -ForegroundColor Cyan
    } catch {}
    return
}
$Cmd = $Arguments[0].ToLower()
if ($Cmd -eq "mute") {
    [Audio]::keybd_event([Audio]::VK_VOLUME_MUTE, 0, [Audio]::KEYEVENTF_KEYDOWN, 0)
    [Audio]::keybd_event([Audio]::VK_VOLUME_MUTE, 0, [Audio]::KEYEVENTF_KEYUP, 0)
    Write-Host "[OK] Audio muted." -ForegroundColor Green
} elseif ($Cmd -eq "unmute") {
    try { (New-Object -ComObject WScript.Shell).SendKeys([char]174) } catch {}
    Write-Host "[OK] Audio unmuted (toggle)." -ForegroundColor Green
} elseif ($Cmd -eq "toggle") {
    [Audio]::keybd_event([Audio]::VK_VOLUME_MUTE, 0, [Audio]::KEYEVENTF_KEYDOWN, 0)
    [Audio]::keybd_event([Audio]::VK_VOLUME_MUTE, 0, [Audio]::KEYEVENTF_KEYUP, 0)
    Write-Host "[OK] Audio mute toggled." -ForegroundColor Green
} elseif ($Cmd -match '^\d+$') {
    $Target = [Math]::Max(0, [Math]::Min(100, [int]$Cmd))
    try {
        $Obj = New-Object -ComObject WScript.Shell
        for ($i = 0; $i -lt 50; $i++) { $Obj.SendKeys([char]174) }
        $Steps = [int]($Target / 2)
        for ($i = 0; $i -lt $Steps; $i++) { $Obj.SendKeys([char]175) }
        Write-Host "[OK] Volume set to $Target%." -ForegroundColor Green
    } catch {
        Write-Host "[FAIL] Could not set volume: $_" -ForegroundColor Red
    }
} else {
    Write-Host "[ERROR] Usage: audio <0-100> | audio mute | audio unmute | audio toggle" -ForegroundColor Red
}
