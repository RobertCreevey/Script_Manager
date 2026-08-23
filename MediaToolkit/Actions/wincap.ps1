# Type: Action
# Description: Captures the foreground (active) window to a PNG file (default Desktop). Unlike the primary-screen shot, this grabs only the active window.
param($Config, [array]$Arguments)
$C = if ($global:ToolColors) { $global:ToolColors } else { [PSCustomObject]@{}}
$ArgsOnly = @($Arguments | Where-Object { $_ -notin @("-Force", "-f") })
$Out = if ($ArgsOnly[0]) { $ArgsOnly[0] } else { Join-Path $env:USERPROFILE "Desktop\window_$(Get-Date -Format yyyyMMdd_HHmmss).png" }
Add-Type -TypeDefinition @'
using System; using System.Runtime.InteropServices; using System.Drawing; using System.Drawing.Imaging;
public class WinCap {
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hwnd, out RECT lpRect);
    [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr hwnd, IntPtr hdcBlt, uint nFlags);
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
    public static void CaptureWindow(string path) {
        IntPtr hwnd = GetForegroundWindow();
        RECT rc; GetWindowRect(hwnd, out rc);
        int w = rc.Right - rc.Left, h = rc.Bottom - rc.Top;
        using (Bitmap bmp = new Bitmap(w, h)) {
            using (Graphics g = Graphics.FromImage(bmp)) {
                IntPtr hdc = g.GetHdc();
                PrintWindow(hwnd, hdc, 0);
                g.ReleaseHdc(hdc);
            }
            bmp.Save(path, ImageFormat.Png);
        }
    }
}
'@ -ErrorAction SilentlyContinue
try {
    [WinCap]::CaptureWindow($Out)
    Write-Host "[OK] Foreground window captured: $Out" -ForegroundColor Green
} catch {
    Write-Host "[FAIL] Window capture failed: $_" -ForegroundColor Red
}
