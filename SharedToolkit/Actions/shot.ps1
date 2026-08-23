# Type: Action
# Description: Captures the local primary screen to a PNG file (default: Desktop) and reports the path.
param($Config, [array]$Arguments)
Add-Type -AssemblyName System.Windows.Forms, System.Drawing
$Out = if ($Arguments[0]) { $Arguments[0] } else { Join-Path $env:USERPROFILE "Desktop\shot_$(Get-Date -Format yyyyMMdd_HHmmss).png" }
$Bounds = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
$Bmp = New-Object System.Drawing.Bitmap($Bounds.Width, $Bounds.Height)
$G = [System.Drawing.Graphics]::FromImage($Bmp)
$G.CopyFromScreen($Bounds.Location, [System.Drawing.Point]::Empty, $Bounds.Size)
$Bmp.Save($Out); $G.Dispose(); $Bmp.Dispose()
Write-Host "[shot] Saved: $Out" -ForegroundColor Green
