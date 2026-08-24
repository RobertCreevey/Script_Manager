# Type: Action
# Description: Lists all connected displays/monitors with resolution, refresh rate, and primary display flag.
param($Config, [array]$Arguments)
$C = Get-ToolkitColors
Write-Host "[monitors] Connected displays..." -ForegroundColor Cyan
try {
    Add-Type -AssemblyName System.Windows.Forms
    $Screens = [System.Windows.Forms.Screen]::AllScreens
    foreach ($S in $Screens) {
        $Primary = if ($S.Primary) { "$($C.Ok) [PRIMARY]$($C.Reset)" } else { "" }
        Write-Host "  $($C.Sys)$($S.DeviceName)$($C.Reset)$Primary"
        Write-Host "    Resolution : $($C.Str)$($S.Bounds.Width)x$($S.Bounds.Height)$($C.Reset)"
        Write-Host "    Position   : $($C.Str)$($S.Bounds.X),$($S.Bounds.Y)$($C.Reset)"
        Write-Host "    WorkingArea: $($C.Str)$($S.WorkingArea.Width)x$($S.WorkingArea.Height)$($C.Reset)"
    }
} catch {
    Write-Host "[FAIL] Monitor enum failed: $_" -ForegroundColor Red
}

