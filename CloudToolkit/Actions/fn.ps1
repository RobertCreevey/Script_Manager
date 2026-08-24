# Type: Action
# Description: Manages serverless functions (Lambda, Functions, Cloud Functions).
param($Config, [array]$Arguments)
$C = Get-ToolkitColors
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
            'aws'  { & aws lambda list-functions --query 'Functions[].[FunctionName,Runtime,LastModified,MemorySize,Timeout]' --output json $CommonArgs | ConvertFrom-Json | ForEach-Object { [PSCustomObject]@{ Name=$_[0]; Runtime=$_[1]; Modified=$_[2]; Memory=$_[3]; Timeout=$_[4] } } }
            'azure' { & az functionapp list --query '[].{Name:name, Runtime:siteConfig.linuxFxVersion, Location:location, State:state}' --output json | ConvertFrom-Json }
            'gcp'  { & gcloud functions list --format='json(name,status,runtime,availableMemoryMb,timeout)' --project $Project | ConvertFrom-Json }
        }
        $Results | Format-ToolOutput -Format $Format
    }
    'invoke' {
        if (-not $Name) { Write-Host "$($C.Warn)[ERROR] Usage: fn invoke <name> [payload.json]$($C.Reset)" ; return }
        $Payload = if ($ArgsOnly[2]) { "file://$($ArgsOnly[2])" } else { '{}' }
        switch ($Provider) {
            'aws'  { & aws lambda invoke --function-name $Name --payload $Payload /dev/stdout $CommonArgs }
            'azure' { Write-Host "$($C.Warn)Azure: use 'func' CLI or HTTP trigger$($C.Reset)" }
            'gcp'  { & gcloud functions call $Name --data=$Payload --project $Project }
        }
    }
    'logs' {
        if (-not $Name) { Write-Host "$($C.Warn)[ERROR] Usage: fn logs <name> [-f]$($C.Reset)" ; return }
        $Follow = $Arguments -contains '-f'
        switch ($Provider) {
            'aws'  { if ($Follow) { & aws logs tail "/aws/lambda/$Name" --follow $CommonArgs } else { & aws logs tail "/aws/lambda/$Name" $CommonArgs } }
            'azure' { & az functionapp log tail --name $Name --resource-group (az functionapp show -n $Name --query resourceGroup -o tsv) }
            'gcp'  { & gcloud functions logs read $Name --project $Project @(if($Follow){"--limit=100"}) }
        }
    }
    'deploy' {
        if (-not $Name) { Write-Host "$($C.Warn)[ERROR] Usage: fn deploy <name> --zip <file> [--handler <handler>] [--runtime <runtime>]$($C.Reset)" ; return }
        # Implementation varies by provider - placeholder
        Write-Host "$($C.Warn)Deploy not implemented - use provider CLI directly$($C.Reset)"
    }
    default { Write-Host "$($C.Warn)[ERROR] Usage: fn [list|invoke|logs|deploy] ...$($C.Reset)" }
}
