# Type: Action
# Description: Lists compute instances (EC2, VMs, Compute Engine) with filtering and output formats.
param($Config, [array]$Arguments)
$C = if ($global:ToolColors) { $global:ToolColors } else { [PSCustomObject]@{}}
$ArgsOnly = @($Arguments | Where-Object { $_ -notin @("-Force", "-f", "-json", "-csv", "-raw", "-table") })
$Format = "table"
if ($Arguments -contains '-json') { $Format = 'json' } elseif ($Arguments -contains '-csv') { $Format = 'csv' } elseif ($Arguments -contains '-raw') { $Format = 'raw' }
$Filter = $ArgsOnly[0]
$Provider = $Config.Provider
$Region = $Config.Region
$Profile = $Config.Profile

$CommonArgs = @("--region", $Region, "--profile", $Profile) | Where-Object { $_ }

$Instances = switch ($Provider) {
    'aws' {
        $Cmd = "aws ec2 describe-instances --query 'Reservations[].Instances[].[InstanceId,State.Name,InstanceType,Placement.AvailabilityZone,Tags[?Key==`Name`].Value|[0],PrivateIpAddress,PublicIpAddress]' --output json $($CommonArgs -join ' ')"
        $Raw = & powershell -NoProfile -Command $Cmd | ConvertFrom-Json
        $Raw | ForEach-Object { [PSCustomObject]@{ Id=$_[0]; State=$_[1]; Type=$_[2]; AZ=$_[3]; Name=$_[4]; PrivateIP=$_[5]; PublicIP=$_[6] } }
    }
    'azure' {
        $Cmd = "az vm list --query '[].{Name:name, ResourceGroup:resourceGroup, Location:location, Size:hardwareProfile.vmSize, PowerState:powerState, PrivateIP:privateIps[0], PublicIP:publicIps[0]}' --output json"
        $Raw = & powershell -NoProfile -Command $Cmd | ConvertFrom-Json
        $Raw | ForEach-Object { [PSCustomObject]@{ Id=$_.Name; State=$_.PowerState; Type=$_.Size; AZ=$_.Location; Name=$_.Name; PrivateIP=$_.PrivateIP; PublicIP=$_.PublicIP } }
    }
    'gcp' {
        $Cmd = "gcloud compute instances list --format='json(name,status,machineType,zone,networkInterfaces[0].networkIP,networkInterfaces[0].accessConfigs[0].natIP)' --project $($Config.Project)"
        $Raw = & powershell -NoProfile -Command $Cmd | ConvertFrom-Json
        $Raw | ForEach-Object {
            $Zone = $_.zone -split '/' | Select-Object -Last 1
            $Type = $_.machineType -split '/' | Select-Object -Last 1
            [PSCustomObject]@{ Id=$_.name; State=$_.status; Type=$Type; AZ=$Zone; Name=$_.name; PrivateIP=$_.networkInterfaces[0].networkIP; PublicIP=$_.networkInterfaces[0].accessConfigs[0].natIP }
        }
    }
}

if ($Filter) { $Instances = $Instances | Where-Object { $_.Name -like "*$Filter*" -or $_.Id -like "*$Filter*" -or $_.State -like "*$Filter*" } }

$Instances | Format-ToolOutput -Format $Format