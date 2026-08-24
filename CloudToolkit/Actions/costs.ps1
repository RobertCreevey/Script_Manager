# Type: Action
# Description: Shows estimated costs and billing info for the current cloud provider.
param($Config, [array]$Arguments)
$C = if ($global:ToolColors) { $global:ToolColors } else { [PSCustomObject]@{}}
$ArgsOnly = @($Arguments | Where-Object { $_ -notin @("-Force", "-f", "-json", "-csv", "-raw", "-table") })
$Format = "table"
if ($Arguments -contains '-json') { $Format = 'json' } elseif ($Arguments -contains '-csv') { $Format = 'csv' } elseif ($Arguments -contains '-raw') { $Format = 'raw' }
$Provider = $Config.Provider
$Region = $Config.Region
$Profile = $Config.Profile
$Project = $Config.Project

$CommonArgs = @("--region", $Region, "--profile", $Profile) | Where-Object { $_ }

$Results = switch ($Provider) {
    'aws' {
        $Start = (Get-Date).AddDays(-30).ToString('yyyy-MM-dd')
        $End = (Get-Date).ToString('yyyy-MM-dd')
        & aws ce get-cost-and-usage --time-period Start=$Start,End=$End --granularity MONTHLY --metrics BlendedCost --output json $CommonArgs | ConvertFrom-Json
    }
    'azure' {
        & az consumption usage list --output json | ConvertFrom-Json
    }
    'gcp' {
        & gcloud billing accounts list --format='json(name,displayName,open)' | ConvertFrom-Json
    }
}

if ($Results) {
    $Results | Format-ToolOutput -Format $Format
} else {
    Write-Host "$($C.Warn)No cost data available or billing not configured$($C.Reset)"
}