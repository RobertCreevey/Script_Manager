# Type: Action
# Description: Backs up or restores all toolkit configuration (profiles + chains) to/from a timestamped JSON bundle.
param($Config, [array]$Arguments)
$ArgsOnly = @($Arguments | Where-Object { $_ -notin @("-Force", "-f") })
$C = Get-ToolkitColors
$Sub = if ($ArgsOnly[0]) { $ArgsOnly[0].ToLower() } else { "backup" }
$ModulesPath = $null
$BackupDir = "$env:USERPROFILE\Documents\SSHToolkit_Backups"

if ($Sub -eq "restore") {
    $File = if ($ArgsOnly[1]) { $ArgsOnly[1] } else { $null }
    if (-not $File) {
        if (-not (Test-Path $BackupDir)) { Write-Host "$($C.Crit)[ERROR] No backups found.$($C.Reset)" ; return }
        $Backups = Get-ChildItem $BackupDir -Filter "*.json" | Sort-Object LastWriteTime -Descending
        if (-not $Backups) { Write-Host "$($C.Crit)[ERROR] No backups found.$($C.Reset)" ; return }
        Write-Host "$($C.Sys)Available backups:$($C.Reset)"
        $Idx = 0
        foreach ($B in $Backups) { $Idx++; Write-Host "  $($C.Param)$Idx$($C.Reset) $($C.Str)$($B.Name)$($C.Reset) ($([math]::Round($B.Length/1KB,1))KB)" }
        Write-Host ""
        Write-Host "$($C.Sys)Usage:$($C.Reset) $($C.Param)restore <filename-or-index>$($C.Reset)"
        return
    }
    if ($File -match '^\d+$') {
        $Backups = Get-ChildItem $BackupDir -Filter "*.json" | Sort-Object LastWriteTime -Descending
        $File = $Backups[[int]$File - 1].FullName
    }
    if (-not (Test-Path $File)) { Write-Host "$($C.Crit)[ERROR] Backup file not found: $File$($C.Reset)" ; return }
    try {
        $Bundle = Get-Content $File -Raw | ConvertFrom-Json
    } catch { Write-Host "$($C.Crit)[ERROR] Could not parse backup: $_$($C.Reset)" ; return }
    $Restored = 0
    foreach ($ToolkitBundle in $Bundle.Toolkits.PSObject.Properties) {
        $ToolkitName = $ToolkitBundle.Name
        $ToolkitPath = Get-ToolkitInstallPath -ToolkitName $ToolkitName
        if (-not $ToolkitPath) { continue }
        $DestBase = $ToolkitPath
        if (-not (Test-Path $DestBase)) { New-Item -ItemType Directory -Path $DestBase -Force | Out-Null }
        foreach ($Prof in $ToolkitBundle.Value.Profiles.PSObject.Properties) {
            $Prof | ConvertTo-Json -Depth 5 | ConvertFrom-Json | ConvertTo-Json -Depth 5 | Out-File "$DestBase\Profiles\$($Prof.Name).json" -Force
            $Restored++
        }
        if ($ToolkitBundle.Value.Chains) {
            if (-not (Test-Path "$DestBase\Chains")) { New-Item -ItemType Directory -Path "$DestBase\Chains" -Force | Out-Null }
            foreach ($Ch in $ToolkitBundle.Value.Chains.PSObject.Properties) {
                $Ch | ConvertTo-Json -Depth 5 | ConvertFrom-Json | ConvertTo-Json -Depth 5 | Out-File "$DestBase\Chains\$($Ch.Name).json" -Force
                $Restored++
            }
        }
    }
    Write-Host "[OK] Restored $Restored item(s) from $($C.Str)$(Split-Path $File -Leaf)$($C.Reset)" -ForegroundColor Green
    return
}

if ($Sub -eq "list") {
    if (-not (Test-Path $BackupDir)) { Write-Host "$($C.Crit)[ERROR] No backups found.$($C.Reset)" ; return }
    $Backups = Get-ChildItem $BackupDir -Filter "*.json" | Sort-Object LastWriteTime -Descending
    if (-not $Backups) { Write-Host "$($C.Crit)[ERROR] No backups found.$($C.Reset)" ; return }
    Write-Host "$($C.Sys)Available backups:$($C.Reset)"
    foreach ($B in $Backups) { Write-Host "  $($C.Str)$($B.Name)$($C.Reset) ($([math]::Round($B.Length/1KB,1))KB)" }
    return
}

if (-not (Test-Path $BackupDir)) { New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null }
$ToolkitFolders = foreach ($Tk in @(Get-Module -ListAvailable -ErrorAction SilentlyContinue | Where-Object { $_.Name -like '*Toolkit' } | Select-Object -Unique -ExpandProperty Name | Sort-Object)) {
    $Path = Get-ToolkitInstallPath -ToolkitName $Tk
    if ($Path -and (Test-Path "$Path\$Tk.psm1")) { [PSCustomObject]@{ Name = $Tk; FullName = $Path } }
}
$Bundle = [ordered]@{ Created = Get-Date -Format "yyyy-MM-dd HH:mm:ss"; Toolkits = [ordered]@{} }
foreach ($Folder in $ToolkitFolders) {
    $TName = $Folder.Name
    $Profiles = @(Get-ChildItem "$Folder\Profiles\*.json" -ErrorAction SilentlyContinue)
    $Chains = @(Get-ChildItem "$Folder\Chains\*.json" -ErrorAction SilentlyContinue)
    if ($Profiles.Count -eq 0 -and $Chains.Count -eq 0) { continue }
    $TData = [ordered]@{ Profiles = [ordered]@{}; Chains = [ordered]@{} }
    foreach ($P in $Profiles) { $TData.Profiles[$P.BaseName] = Get-Content $P.FullName -Raw | ConvertFrom-Json }
    foreach ($Ch in $Chains) { $TData.Chains[$Ch.BaseName] = Get-Content $Ch.FullName -Raw | ConvertFrom-Json }
    $Bundle.Toolkits[$TName] = $TData
}
$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$BackupFile = "$BackupDir\toolkit_backup_$Timestamp.json"
$Bundle | ConvertTo-Json -Depth 6 | Out-File $BackupFile -Force
$TotalProfiles = ($Bundle.Toolkits.PSObject.Properties | ForEach-Object { $_.Value.Profiles.Count } | Measure-Object -Sum).Sum
$TotalChains = ($Bundle.Toolkits.PSObject.Properties | ForEach-Object { $_.Value.Chains.Count } | Measure-Object -Sum).Sum
Write-Host "[OK] Backup saved: $($C.Str)$(Split-Path $BackupFile -Leaf)$($C.Reset)" -ForegroundColor Green
Write-Host "  $($C.Param)$($Bundle.Toolkits.Count) toolkits$($C.Reset), $($C.Param)$TotalProfiles profiles$($C.Reset), $($C.Param)$TotalChains chains$($C.Reset)"

