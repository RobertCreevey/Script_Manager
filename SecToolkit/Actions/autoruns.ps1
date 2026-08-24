# Type: Action
# Description: Lists auto-start programs from Run keys and startup folders (current user and local machine).
param($Config, [array]$Arguments)
$C = Get-ToolkitColors
Write-Host "[autoruns] Auto-start entries..." -ForegroundColor Cyan
try {
    $Locations = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run',
        'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run'
    )
    foreach ($Loc in $Locations) {
        $Items = Get-ItemProperty -Path $Loc -ErrorAction SilentlyContinue
        if ($Items) {
            Write-Host "  $($C.Sys)$Loc$($C.Reset)" -ForegroundColor Yellow
            $Items.PSObject.Properties | Where-Object { $_.Name -notmatch '^PS' } | ForEach-Object {
                Write-Host "    $($C.Str)$($_.Name)$($C.Reset) → $($_.Value)"
            }
        }
    }
    $StartupFolders = @("$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup", "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Startup")
    foreach ($F in $StartupFolders) {
        if (Test-Path $F) {
            Write-Host "  $($C.Sys)$F$($C.Reset)" -ForegroundColor Yellow
            Get-ChildItem $F -ErrorAction SilentlyContinue | ForEach-Object { Write-Host "    $($C.Str)$($_.Name)$($C.Reset)" }
        }
    }
} catch {
    Write-Host "[FAIL] Could not enumerate autoruns: $_" -ForegroundColor Red
}

