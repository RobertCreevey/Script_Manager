# Type: Action
# Description: Lists or sets the display resolution. Use 'display list' to show modes, or 'display <width> <height>' to change. Requires confirmation unless -Force.
param($Config, [array]$Arguments)
$C = Get-ToolkitColors
$ArgsOnly = @($Arguments | Where-Object { $_ -notin @("-Force", "-f") })
Add-Type -TypeDefinition @'
using System; using System.Runtime.InteropServices;
public class Display {
    [DllImport("user32.dll")] public static extern bool EnumDisplaySettings(string deviceName, int modeNum, ref DEVMODE devMode);
    [DllImport("user32.dll")] public static extern int ChangeDisplaySettings(ref DEVMODE devMode, int flags);
    [StructLayout(LayoutKind.Sequential)] public struct DEVMODE {
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst=32)] public string dmDeviceName;
        public short dmSpecVersion, dmDriverVersion, dmSize, dmDriverExtra;
        public int dmFields;
        public int dmPositionX, dmPositionY;
        public int dmDisplayOrientation, dmDisplayFixedOutput;
        public short dmColor, dmDuplex, dmYResolution, dmTTOption, dmCollate;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst=32)] public string dmFormName;
        public short dmLogPixels; public int dmBitsPerPel;
        public int dmPelsWidth, dmPelsHeight;
        public int dmDisplayFlags, dmDisplayFrequency;
    }
}
'@ -ErrorAction SilentlyContinue
function Get-Modes {
    $Mode = New-Object Display+DEVMODE; $Mode.dmSize = [System.Runtime.InteropServices.Marshal]::SizeOf($Mode)
    $Idx = 0
    while ([Display]::EnumDisplaySettings($null, $Idx, [ref]$Mode)) {
        Write-Host "  $($C.Str)$($Mode.dmPelsWidth)x$($Mode.dmPelsHeight)$($C.Reset) @ $($Mode.dmDisplayFrequency)Hz ($($Mode.dmBitsPerPel)-bit)"
        $Idx++
    }
}
if ($ArgsOnly.Count -eq 0 -or $ArgsOnly[0] -eq "list") {
    Write-Host "[display] Available modes:" -ForegroundColor Cyan
    Get-Modes
    return
}
if ($ArgsOnly.Count -ge 2 -and $ArgsOnly[0] -match '^\d+$' -and $ArgsOnly[1] -match '^\d+$') {
    $W = [int]$ArgsOnly[0]; $H = [int]$ArgsOnly[1]
    if (-not (Request-ToolkitConfirmation -Verb "change resolution" -Command "${W}x$H" -Config $Config -Arguments $Arguments -Dangerous)) { return }
    $Mode = New-Object Display+DEVMODE; $Mode.dmSize = [System.Runtime.InteropServices.Marshal]::SizeOf($Mode)
    $Mode.dmPelsWidth = $W; $Mode.dmPelsHeight = $H; $Mode.dmFields = 0x00080000 -bor 0x00100000
    $R = [Display]::ChangeDisplaySettings([ref]$Mode, 0)
    if ($R -eq 0) { Write-Host "[OK] Resolution changed to ${W}x$H." -ForegroundColor Green }
    else { Write-Host "[WARN] Display result code $R (may require logout)." -ForegroundColor Yellow }
} else {
    Write-Host "[ERROR] Usage: display list | display <width> <height>" -ForegroundColor Red
}


