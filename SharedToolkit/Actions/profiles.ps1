# Type: Action
# Description: Manage profiles across all toolkits - list, show, create, delete, export.
param($Config, [array]$Arguments)

$C = Get-ToolkitColors
$Action = if ($Arguments.Count -gt 0) { $Arguments[0] } else { "list" }
$Toolkit = ""
$Name = ""
$Format = "table"

for ($i = 1; $i -lt $Arguments.Count; $i++) {
    switch ($Arguments[$i]) {
        '-toolkit' { if ($i+1 -lt $Arguments.Count) { $Toolkit = $Arguments[++$i] } }
        '-name'    { if ($i+1 -lt $Arguments.Count) { $Name = $Arguments[++$i] } }
        '-json'    { $Format = 'json' }
        '-csv'     { $Format = 'csv' }
        '-raw'     { $Format = 'raw' }
    }
}

$AllToolkits = @("SSHToolkit", "NetToolkit", "MediaToolkit", "SecToolkit", "FileToolkit", "SharedToolkit")
if ($Toolkit) { $AllToolkits = @($Toolkit) }

function Get-Profiles {
    $Results = @()
    foreach ($Tk in $AllToolkits) {
        $ProfilePath = "$env:USERPROFILE\Documents\PowerShell\Modules\$Tk\Profiles"
        if (Test-Path $ProfilePath) {
            Get-ChildItem "$ProfilePath\*.json" -ErrorAction SilentlyContinue | ForEach-Object {
                $Content = Get-Content $_.FullName -Raw -ErrorAction SilentlyContinue | ConvertFrom-Json -ErrorAction SilentlyContinue
                $Results += [PSCustomObject]@{
                    Toolkit = $Tk
                    Name    = $_.BaseName
                    Path    = $_.FullName
                    Config  = $Content
                    Size    = $_.Length
                }
            }
        }
    }
    return $Results
}

switch ($Action) {
    'list' {
        $Profiles = Get-Profiles
        if (-not $Profiles) { Write-Host "$($C.Warn)No profiles found$($C.Reset)"; return }
        if ($Format -eq 'json') { $Profiles | Select-Object Toolkit, Name, Size | ConvertTo-Json -Depth 3 }
        elseif ($Format -eq 'csv') { $Profiles | Select-Object Toolkit, Name, Size | ConvertTo-Csv -NoTypeInformation }
        elseif ($Format -eq 'raw') { $Profiles | ForEach-Object { "$($_.Toolkit)/$($_.Name)" } }
        else { $Profiles | Format-Table -AutoSize Toolkit, Name, @{Name='Size(KB)';Expression={[math]::Round($_.Size/1KB,1)}} }
    }
    'show' {
        if (-not $Name) { Write-Host "$($C.Warn)Usage: profiles show -name <name> [-toolkit <tk>]$($C.Reset)"; return }
        $Profile = Get-Profiles | Where-Object { $_.Name -eq $Name }
        if (-not $Profile) { Write-Host "$($C.Warn)Profile '$Name' not found$($C.Reset)"; return }
        if ($Format -eq 'json') { $Profile.Config | ConvertTo-Json -Depth 5 }
        elseif ($Format -eq 'raw') { $Profile.Config | ConvertTo-Json -Depth 5 }
        else { $Profile.Config | Format-List * }
    }
    'create' {
        if (-not $Name -or -not $Toolkit) { Write-Host "$($C.Warn)Usage: profiles create -name <name> -toolkit <tk> [-json <config>]$($C.Reset)"; return }
        $ProfilePath = "$env:USERPROFILE\Documents\PowerShell\Modules\$Toolkit\Profiles"
        if (-not (Test-Path $ProfilePath)) { New-Item -ItemType Directory -Path $ProfilePath -Force | Out-Null }
        $FilePath = "$ProfilePath\$Name.json"
        if (Test-Path $FilePath) { Write-Host "$($C.Warn)Profile '$Name' already exists in $Toolkit$($C.Reset)"; return }
        $DefaultConfig = @{ IP = ""; Port = 22; User = ""; Key = ""; Timeout = 30 }
        $DefaultConfig | ConvertTo-Json -Depth 3 | Out-File $FilePath -Encoding utf8
        Write-Host "$($C.Ok)Created profile '$Name' in $Toolkit$($C.Reset)"
    }
    'delete' {
        if (-not $Name) { Write-Host "$($C.Warn)Usage: profiles delete -name <name> [-toolkit <tk>]$($C.Reset)"; return }
        $Deleted = $false
        foreach ($Tk in $AllToolkits) {
            $FilePath = "$env:USERPROFILE\Documents\PowerShell\Modules\$Tk\Profiles\$Name.json"
            if (Test-Path $FilePath) {
                Remove-Item $FilePath -Force
                Write-Host "$($C.Ok)Deleted profile '$Name' from $Tk$($C.Reset)"
                $Deleted = $true
            }
        }
        if (-not $Deleted) { Write-Host "$($C.Warn)Profile '$Name' not found$($C.Reset)" }
    }
    'export' {
        if (-not $Name) { Write-Host "$($C.Warn)Usage: profiles export -name <name> [-toolkit <tk>] [-json|-csv]$($C.Reset)"; return }
        $Profile = Get-Profiles | Where-Object { $_.Name -eq $Name }
        if (-not $Profile) { Write-Host "$($C.Warn)Profile '$Name' not found$($C.Reset)"; return }
        if ($Format -eq 'json') { $Profile.Config | ConvertTo-Json -Depth 5 }
        elseif ($Format -eq 'csv') { $Profile.Config.PSObject.Properties | ForEach-Object { "$($_.Name),$($_.Value)" } }
        else { $Profile.Config | Format-List * }
    }
    'import' {
        if (-not $Name -or -not $Toolkit) { Write-Host "$($C.Warn)Usage: profiles import -name <name> -toolkit <tk> -json <file>$($C.Reset)"; return }
        # Implementation would read JSON from stdin or file and save
        Write-Host "$($C.Warn)Import not yet implemented$($C.Reset)"
    }
    default {
        Write-Host "$($C.Info)Usage: profiles <list|show|create|delete|export> [options]$($C.Reset)"
        Write-Host "$($C.Str)  list                     List all profiles$($C.Reset)"
        Write-Host "$($C.Str)  show -name <name>        Show profile details$($C.Reset)"
        Write-Host "$($C.Str)  create -name -toolkit    Create new profile$($C.Reset)"
        Write-Host "$($C.Str)  delete -name             Delete profile$($C.Reset)"
        Write-Host "$($C.Str)  export -name             Export profile$($C.Reset)"
        Write-Host "$($C.Str)  Options: -toolkit, -json, -csv, -raw$($C.Reset)"
    }
}
