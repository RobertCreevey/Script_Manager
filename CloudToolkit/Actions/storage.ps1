# Type: Action
# Description: Manages cloud storage (S3, Blob Storage, Cloud Storage) - list, sync, cp, rm.
param($Config, [array]$Arguments)
$C = if ($global:ToolColors) { $global:ToolColors } else { [PSCustomObject]@{}}
$ArgsOnly = @($Arguments | Where-Object { $_ -notin @("-Force", "-f", "-json", "-csv", "-raw", "-table", "-r", "-R") })
$Format = "table"
if ($Arguments -contains '-json') { $Format = 'json' } elseif ($Arguments -contains '-csv') { $Format = 'csv' } elseif ($Arguments -contains '-raw') { $Format = 'raw' }
$Recursive = $Arguments -contains '-r' -or $Arguments -contains '-R'
$Sub = if ($ArgsOnly[0]) { $ArgsOnly[0] } else { 'ls' }
$Target = $ArgsOnly[1]
$Dest = $ArgsOnly[2]
$Provider = $Config.Provider
$Region = $Config.Region
$Profile = $Config.Profile
$Project = $Config.Project

$CommonArgs = @("--region", $Region, "--profile", $Profile) | Where-Object { $_ }

switch ($Sub) {
    'ls' {
        if (-not $Target) { Write-Host "$($C.Warn)[ERROR] Usage: storage ls <bucket|container> [prefix]$($C.Reset)" ; return }
        $Results = switch ($Provider) {
            'aws'  { & aws s3 ls "s3://$Target" $CommonArgs --recursive:$Recursive }
            'azure' { & az storage blob list --container-name $Target --output table --auth-mode login }
            'gcp'  { & gsutil ls -r "gs://$Target**" }
        }
        if ($Format -ne 'table') { $Results | Format-ToolOutput -Format $Format } else { $Results }
    }
    'cp' {
        if (-not $Target -or -not $Dest) { Write-Host "$($C.Warn)[ERROR] Usage: storage cp <src> <dst>$($C.Reset)" ; return }
        switch ($Provider) {
            'aws'  { & aws s3 cp $Target $Dest $CommonArgs @(if($Recursive){"--recursive"}) }
            'azure' { & az storage blob upload --container-name (Split-Path $Dest -Parent) --file $Target --name (Split-Path $Dest -Leaf) --auth-mode login }
            'gcp'  { & gsutil cp @(if($Recursive){"-r"}) $Target $Dest }
        }
    }
    'sync' {
        if (-not $Target -or -not $Dest) { Write-Host "$($C.Warn)[ERROR] Usage: storage sync <src> <dst>$($C.Reset)" ; return }
        switch ($Provider) {
            'aws'  { & aws s3 sync $Target $Dest $CommonArgs }
            'azure' { Write-Host "$($C.Warn)Azure sync: use 'azcopy' or 'az storage blob sync'$($C.Reset)" }
            'gcp'  { & gsutil -m rsync -r $Target $Dest }
        }
    }
    'rm' {
        if (-not $Target) { Write-Host "$($C.Warn)[ERROR] Usage: storage rm <bucket/obj> [-r]$($C.Reset)" ; return }
        if (-not (Assert-ToolkitAction -Verb "delete storage object" -Command "rm $Target" -Config $Config -Arguments $Arguments)) { return }
        switch ($Provider) {
            'aws'  { & aws s3 rm $Target $CommonArgs @(if($Recursive){"--recursive"}) }
            'azure' { & az storage blob delete --container-name (Split-Path $Target -Parent) --name (Split-Path $Target -Leaf) --auth-mode login }
            'gcp'  { & gsutil rm @(if($Recursive){"-r"}) $Target }
        }
    }
    'mb' {
        if (-not $Target) { Write-Host "$($C.Warn)[ERROR] Usage: storage mb <bucket|container>$($C.Reset)" ; return }
        switch ($Provider) {
            'aws'  { & aws s3 mb "s3://$Target" $CommonArgs }
            'azure' { & az storage container create --name $Target --auth-mode login }
            'gcp'  { & gsutil mb "gs://$Target" }
        }
    }
    default { Write-Host "$($C.Warn)[ERROR] Usage: storage [ls|cp|sync|rm|mb] ...$($C.Reset)" }
}