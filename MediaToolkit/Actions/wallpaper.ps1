# Type: Action
# Description: Sets the desktop wallpaper from a local image path (BMP/JPG/PNG). Requires confirmation unless -Force.
param($Config, [array]$Arguments)
$C = if ($global:ToolColors) { $global:ToolColors } else { [PSCustomObject]@{}}
$ArgsOnly = @($Arguments | Where-Object { $_ -notin @("-Force", "-f") })
$Path = if ($ArgsOnly[0]) { $ArgsOnly[0] } else { $null }
if (-not $Path -or -not (Test-Path $Path)) { Write-Host "[ERROR] Provide a valid image path." -ForegroundColor Red ; return }
if (-not (Assert-ToolkitAction -Verb "set wallpaper" -Command $Path -Config $Config -Arguments $Arguments)) { return }
Add-Type -TypeDefinition @'
using System.Runtime.InteropServices;
public class Wallpaper {
    [DllImport("user32.dll", CharSet=CharSet.Auto)] public static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
}
'@ -ErrorAction SilentlyContinue
$R = [Wallpaper]::SystemParametersInfo(20, 0, (Resolve-Path $Path).Path, 0x01 -bor 0x02)
if ($R) { Write-Host "[OK] Wallpaper set to $Path." -ForegroundColor Green }
else { Write-Host "[FAIL] Could not set wallpaper." -ForegroundColor Red }
