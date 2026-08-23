# Type: Action
# Description: Switches or lists the active color theme (default | light | mono) used across the framework.
param($Config, [array]$Arguments)
$ESC = [char]27
$Themes = [PSCustomObject]@{
    default = [PSCustomObject]@{Host="$ESC[38;5;208m";Action="$ESC[38;5;81m";List="$ESC[38;5;119m";Sys="$ESC[38;5;141m";Param="$ESC[38;5;221m";Str="$ESC[38;5;210m";File="$ESC[38;5;45m";Warn="$ESC[38;5;196m";Ok="$ESC[38;5;120m";Info="$ESC[38;5;39m";Crit="$ESC[38;5;197m";Reset="$ESC[0m"}
    light  = [PSCustomObject]@{Host="$ESC[38;5;202m";Action="$ESC[38;5;25m";List="$ESC[38;5;28m";Sys="$ESC[38;5;93m";Param="$ESC[38;5;130m";Str="$ESC[38;5;232m";File="$ESC[38;5;31m";Warn="$ESC[38;5;160m";Ok="$ESC[38;5;22m";Info="$ESC[38;5;27m";Crit="$ESC[38;5;124m";Reset="$ESC[0m"}
    mono   = [PSCustomObject]@{Host="$ESC[1;37m";Action="$ESC[1;36m";List="$ESC[1;32m";Sys="$ESC[1;35m";Param="$ESC[1;33m";Str="$ESC[0;37m";File="$ESC[1;34m";Warn="$ESC[1;31m";Ok="$ESC[1;32m";Info="$ESC[1;36m";Crit="$ESC[1;31m";Reset="$ESC[0m"}
}
$Sel = if ($Arguments[0]) { $Arguments[0] } else { $null }
if ($Sel -and $Themes.PSObject.Properties[$Sel]) {
    $Src = $Themes.$Sel
    $New = [PSCustomObject]@{}
    foreach ($p in $Src.PSObject.Properties) { $New | Add-Member -NotePropertyName $p.Name -NotePropertyValue $p.Value }
    $global:ToolColors = $New
    Write-Host "[OK] Theme set to '$Sel'." -ForegroundColor Green
} else {
    Write-Host "Available themes: $($Themes.PSObject.Properties.Name -join ', ')" -ForegroundColor Cyan
    Write-Host "Usage: theme <name>   (current applied at module import is 'default')" -ForegroundColor Gray
}
