# Type: Action
# Description: Shows the current UAC (User Account Control) elevation prompt level and consent behavior.
param($Config, [array]$Arguments)
$C = if ($global:ToolColors) { $global:ToolColors } else { [PSCustomObject]@{}}
Write-Host "[uac] User Account Control settings..." -ForegroundColor Cyan
try {
    $Keys = @(
        @{Path='HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System'; Name='ConsentPromptBehaviorAdmin'; Desc='Admin prompt behavior'},
        @{Path='HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System'; Name='EnableLUA'; Desc='UAC enabled'},
        @{Path='HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System'; Name='PromptOnSecureDesktop'; Desc='Secure desktop prompt'}
    )
    foreach ($K in $Keys) {
        $Val = (Get-ItemProperty -Path $K.Path -Name $K.Name -ErrorAction SilentlyContinue).$($K.Name)
        Write-Host "  $($C.Sys)$($K.Desc):$($C.Reset) $($C.Str)$Val$($C.Reset)"
    }
} catch {
    Write-Host "[FAIL] Could not read UAC settings: $_" -ForegroundColor Red
}
