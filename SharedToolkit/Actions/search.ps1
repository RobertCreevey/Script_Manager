# Type: Action
# Description: Searches across all installed toolkit actions, commands, and help text.
param($Config, [array]$Arguments)

$C = if ($global:ToolColors) { $global:ToolColors } else { [PSCustomObject]@{}}
$Query = $Arguments -join ' '
$AllToolkits = @("SSHToolkit", "NetToolkit", "MediaToolkit", "SecToolkit", "FileToolkit", "SharedToolkit")
$Results = @()

foreach ($Toolkit in $AllToolkits) {
    $ActionsPath = "$global:SharedToolkitPath\..\$Toolkit\Actions"
    if (Test-Path $ActionsPath) {
        $Files = Get-ChildItem "$ActionsPath\*.ps1" -ErrorAction SilentlyContinue
        foreach ($File in $Files) {
            $Content = Get-Content $File.FullName -Raw -ErrorAction SilentlyContinue
            $Type = ""
            $Description = ""
            if ($Content -match '# Type:\s*(\w+)') { $Type = $matches[1] }
            if ($Content -match '# Description:\s*(.+)') { $Description = $matches[1].Trim() }
            $ActionName = $File.BaseName
            $MatchScore = 0
            $Matches = @()

            if ($ActionName -like "*$Query*") { $MatchScore += 10; $Matches += "name" }
            if ($Type -and $Type -like "*$Query*") { $MatchScore += 5; $Matches += "type" }
            if ($Description -and $Description -like "*$Query*") { $MatchScore += 5; $Matches += "description" }
            if ($Content -like "*$Query*") { $MatchScore += 1; $Matches += "content" }

            if ($MatchScore -gt 0 -or $Query -eq '') {
                $Results += [PSCustomObject]@{
                    Toolkit    = $Toolkit
                    Action     = $ActionName
                    Type       = $Type
                    Description = $Description
                    Path       = $File.FullName
                    Score      = $MatchScore
                    MatchType  = $Matches -join ', '
                }
            }
        }
    }
}

$Sorted = $Results | Sort-Object Score -Descending | Select-Object Toolkit, Action, Type, Description

if ($Sorted.Count -eq 0) {
    Write-Host "$($C.Warn)No actions found matching '$Query'$($C.Reset)"
    return
}

$Format = $Config.SearchFormat ?? "table"
switch ($Format) {
    "json" { $Sorted | ConvertTo-Json -Depth 3 }
    "csv"  { $Sorted | ConvertTo-Csv -NoTypeInformation }
    "raw"  { $Sorted | ForEach-Object { "$($_.Toolkit)/$($_.Action) - $($_.Description)" } }
    default {
        $Sorted | Format-Table -AutoSize -Property @{Name='Toolkit';Expression={$_.Toolkit};Width=14}, @{Name='Action';Expression={$_.Action};Width=18}, @{Name='Type';Expression={$_.Type};Width=10}, @{Name='Description';Expression={$_.Description};Width=50}
        Write-Host "$($C.Muted)($($Sorted.Count) results)$($C.Reset)"
    }
}