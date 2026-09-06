# Type: Action
# Description: Manages secrets (Secrets Manager, Key Vault, Secret Manager).
param($Config, [array]$Arguments)
$C = Get-ToolkitColors
$ArgsOnly = @($Arguments | Where-Object { $_ -notin @("-Force", "-f", "-json", "-csv", "-raw", "-table") })
$Format = "table"
if ($Arguments -contains '-json') { $Format = 'json' } elseif ($Arguments -contains '-csv') { $Format = 'csv' } elseif ($Arguments -contains '-raw') { $Format = 'raw' }
$Sub = if ($ArgsOnly[0]) { $ArgsOnly[0] } else { 'list' }
$Name = $ArgsOnly[1]
$Value = $ArgsOnly[2]
$Provider = $Config.Provider
$Region = $Config.Region
$Profile = $Config.Profile
$Project = $Config.Project

$CommonArgs = @("--region", $Region, "--profile", $Profile) | Where-Object { $_ }

switch ($Sub) {
    'list' {
        $Results = switch ($Provider) {
            'aws'  { & aws secretsmanager list-secrets --query 'SecretList[].[Name,Description,LastChangedDate]' --output json $CommonArgs | ConvertFrom-Json | ForEach-Object { [PSCustomObject]@{ Name=$_[0]; Desc=$_[1]; Changed=$_[2] } } }
            'azure' { & az keyvault secret list --vault-name $ArgsOnly[1] --output json | ConvertFrom-Json }
            'gcp'  { & gcloud secrets list --format='json(name,replication.policy.userManaged.replicas[].location)' --project $Project | ConvertFrom-Json }
        }
        $Results | Format-ToolOutput -Format $Format
    }
    'get' {
        if (-not $Name) { Write-Host "$($C.Crit)[ERROR] Usage: secrets get <name> [-json]$($C.Reset)" ; return }
        switch ($Provider) {
            'aws'  { & aws secretsmanager get-secret-value --secret-id $Name $CommonArgs --query SecretString --output text }
            'azure' { & az keyvault secret show --vault-name $ArgsOnly[2] --name $Name --query value -o tsv }
            'gcp'  { & gcloud secrets versions access latest --secret=$Name --project $Project }
        }
    }
    'set' {
        if (-not $Name -or -not $Value) { Write-Host "$($C.Crit)[ERROR] Usage: secrets set <name> <value>$($C.Reset)" ; return }
        if (-not (Request-ToolkitConfirmation -Verb "create/update secret" -Command "secrets set $Name" -Config $Config -Arguments $Arguments)) { return }
        switch ($Provider) {
            'aws'  { & aws secretsmanager put-secret-value --secret-id $Name --secret-string $Value $CommonArgs }
            'azure' { & az keyvault secret set --vault-name $ArgsOnly[3] --name $Name --value $Value }
            'gcp'  { echo $Value | & gcloud secrets versions add $Name --data-file=- --project $Project }
        }
    }
    default { Write-Host "$($C.Crit)[ERROR] Usage: secrets [list|get|set] ...$($C.Reset)" }
}

