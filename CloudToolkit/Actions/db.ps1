# Type: Action
# Description: Manages managed databases (RDS, SQL, Cloud SQL).
param($Config, [array]$Arguments)
$C = if ($global:ToolColors) { $global:ToolColors } else { [PSCustomObject]@{}}
$ArgsOnly = @($Arguments | Where-Object { $_ -notin @("-Force", "-f", "-json", "-csv", "-raw", "-table") })
$Format = "table"
if ($Arguments -contains '-json') { $Format = 'json' } elseif ($Arguments -contains '-csv') { $Format = 'csv' } elseif ($Arguments -contains '-raw') { $Format = 'raw' }
$Sub = if ($ArgsOnly[0]) { $ArgsOnly[0] } else { 'list' }
$Name = $ArgsOnly[1]
$Provider = $Config.Provider
$Region = $Config.Region
$Profile = $Config.Profile
$Project = $Config.Project

$CommonArgs = @("--region", $Region, "--profile", $Profile) | Where-Object { $_ }

switch ($Sub) {
    'list' {
        $Results = switch ($Provider) {
            'aws'  { & aws rds describe-db-instances --query 'DBInstances[].[DBInstanceIdentifier,DBInstanceClass,Engine,DBInstanceStatus,Endpoint.Address,AllocatedStorage]' --output json $CommonArgs | ConvertFrom-Json | ForEach-Object { [PSCustomObject]@{ Name=$_[0]; Class=$_[1]; Engine=$_[2]; Status=$_[3]; Endpoint=$_[4]; Storage=$_[5] } } }
            'azure' { & az sql db list --server $ArgsOnly[1] --resource-group $ArgsOnly[2] --output json | ConvertFrom-Json }
            'gcp'  { & gcloud sql instances list --format='json(name,region,databaseVersion,state,settings.tier)' --project $Project | ConvertFrom-Json }
        }
        $Results | Format-ToolOutput -Format $Format
    }
    'connect' {
        if (-not $Name) { Write-Host "$($C.Warn)[ERROR] Usage: db connect <name>$($C.Reset)" ; return }
        Write-Host "$($C.Warn)Connection strings - use provider CLI:$($C.Reset)"
        switch ($Provider) {
            'aws'  { & aws rds generate-db-auth-token --hostname $Name --port 5432 --region $Region --profile $Profile }
            'azure' { & az sql db show-connection-string --client sqlcmd --name $Name --server $ArgsOnly[2] --resource-group $ArgsOnly[3] }
            'gcp'  { & gcloud sql connect $Name --project $Project --user=postgres }
        }
    }
    default { Write-Host "$($C.Warn)[ERROR] Usage: db [list|connect] ...$($C.Reset)" }
}