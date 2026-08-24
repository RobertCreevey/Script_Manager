# Type: Action
# Description: Discovers and displays all installed toolkits with structured, color-coded info. Summary view lists all toolkits; detailed view shows actions, listeners, and profiles for one toolkit.
param($Config, [array]$Arguments)
$C = if ($global:ToolColors) { $global:ToolColors } else { [PSCustomObject]@{} }
$ArgsOnly = @($Arguments | Where-Object { $_ -notin @("-Force", "-f") })
$TargetName = if ($ArgsOnly[0]) { $ArgsOnly[0] } else { $null }

$ModulesPath = "$env:USERPROFILE\Documents\PowerShell\Modules"
if (-not (Test-Path $ModulesPath)) { Write-Host "$($C.Warn)[ERROR] Modules path not found: $ModulesPath$($C.Reset)" ; return }

$ToolkitFolders = Get-ChildItem -Path $ModulesPath -Directory | Where-Object { $_.Name -ne "SharedToolkit" -and (Test-Path "$($_.FullName)\$($_.Name).psm1") }

function Get-ToolkitInfo {
    param([string]$FolderPath, [string]$Name)
    $ManifestFile = "$FolderPath\toolkit.json"
    $Info = [ordered]@{ Name = $Name; Version = "?"; Description = "(no manifest)"; Profiles = @(); Actions = @(); Listeners = @() }
    if (Test-Path $ManifestFile) {
        try {
            $Manifest = Get-Content $ManifestFile -Raw | ConvertFrom-Json
            if ($Manifest.version) { $Info.Version = $Manifest.version }
            if ($Manifest.description) { $Info.Description = $Manifest.description }
            if ($Manifest.profiles) { $Info.Profiles = @($Manifest.profiles) }
            if ($Manifest.actions) { $Info.Actions = @($Manifest.actions) }
            if ($Manifest.listeners) { $Info.Listeners = @($Manifest.listeners) }
        } catch { $Info.Description = "(manifest parse error)" }
    }
    if ($Info.Actions.Count -eq 0) { $Info.Actions = @(Get-ChildItem "$FolderPath\Actions\*.ps1" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty BaseName) }
    if ($Info.Listeners.Count -eq 0) { $Info.Listeners = @(Get-ChildItem "$FolderPath\Listeners\*.ps1" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty BaseName) }
    if ($Info.Profiles.Count -eq 0) { $Info.Profiles = @(Get-ChildItem "$FolderPath\Profiles\*.json" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty BaseName) }
    $Info
}

if ($TargetName) {
    $Folder = $ToolkitFolders | Where-Object { $_.Name -eq $TargetName }
    if (-not $Folder) { Write-Host "$($C.Warn)[ERROR] Toolkit '$TargetName' not found.$($C.Reset)" ; return }
    $Info = Get-ToolkitInfo $Folder.FullName $Folder.Name
    Write-Host ""
    Write-Host "$($C.Sys)═══ TOOLKIT: $($C.Action)$($Info.Name)$($C.Reset) v$($C.Str)$($Info.Version)$($C.Reset) ═══" -ForegroundColor White
    Write-Host "$($C.Str)$($Info.Description)$($C.Reset)"
    Write-Host ""
    Write-Host "$($C.Sys)PROFILES ($($Info.Profiles.Count)):$($C.Reset)"
    if ($Info.Profiles.Count -eq 0) { Write-Host "  (none)" -ForegroundColor Gray }
    foreach ($P in $Info.Profiles) { Write-Host "  $($C.Host)$P$($C.Reset)" }
    Write-Host ""
    Write-Host "$($C.Sys)ACTIONS ($($Info.Actions.Count)):$($C.Reset)"
    foreach ($A in $Info.Actions) { Write-Host "  $($C.Action)$A$($C.Reset)" }
    Write-Host ""
    Write-Host "$($C.Sys)LISTENERS ($($Info.Listeners.Count)):$($C.Reset)"
    if ($Info.Listeners.Count -eq 0) { Write-Host "  (none)" -ForegroundColor Gray }
    foreach ($L in $Info.Listeners) { Write-Host "  $($C.List)$L$($C.Reset)" }
    Write-Host ""
    return
}

Write-Host ""
Write-Host "$($C.Sys)═══ TOOLKIT REGISTRY ═══$($C.Reset)" -ForegroundColor White
Write-Host "$($C.Str)$($ToolkitFolders.Count) toolkits installed$($C.Reset) (parent: $($C.Action)SharedToolkit$($C.Reset))"
Write-Host ""
foreach ($Folder in $ToolkitFolders) {
    $Info = Get-ToolkitInfo $Folder.FullName $Folder.Name
    Write-Host "  $($C.Action)$($Info.Name.PadRight(14))$($C.Reset) v$($C.Str)$($Info.Version)$($C.Reset)  $($C.Param)$($Info.Actions.Count) actions$($C.Reset)  $($C.List)$($Info.Listeners.Count) listeners$($C.Reset)  $($C.Host)$($Info.Profiles.Count) profiles$($C.Reset)"
    Write-Host "    $($C.Str)$($Info.Description)$($C.Reset)"
}
Write-Host ""
Write-Host "$($C.Sys)Usage:$($C.Reset) $($C.Param)registry <name>$($C.Reset) for detailed view"
Write-Host ""
