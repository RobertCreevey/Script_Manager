# Type: Action
# Description: Lists and manages VPCs, subnets, security groups, and network interfaces.
param($Config, [array]$Arguments)
$C = if ($global:ToolColors) { $global:ToolColors } else { [PSCustomObject]@{}}
$ArgsOnly = @($Arguments | Where-Object { $_ -notin @("-Force", "-f", "-json", "-csv", "-raw", "-table") })
$Format = "table"
if ($Arguments -contains '-json') { $Format = 'json' } elseif ($Arguments -contains '-csv') { $Format = 'csv' } elseif ($Arguments -contains '-raw') { $Format = 'raw' }
$Sub = if ($ArgsOnly[0]) { $ArgsOnly[0] } else { 'vpcs' }
$Provider = $Config.Provider
$Region = $Config.Region
$Profile = $Config.Profile
$Project = $Config.Project

$CommonArgs = @("--region", $Region, "--profile", $Profile) | Where-Object { $_ }

switch ($Sub) {
    'vpcs' {
        $Results = switch ($Provider) {
            'aws'  { & aws ec2 describe-vpcs --query 'Vpcs[].[VpcId,State,CidrBlock,IsDefault,Tags[?Key==`Name`].Value|[0]]' --output json $CommonArgs | ConvertFrom-Json | ForEach-Object { [PSCustomObject]@{ Id=$_[0]; State=$_[1]; CIDR=$_[2]; Default=$_[3]; Name=$_[4] } } }
            'azure' { & az network vnet list --query '[].{Name:name, ResourceGroup:resourceGroup, Location:location, AddressSpace:addressSpace.addressPrefixes}' --output json | ConvertFrom-Json }
            'gcp'  { & gcloud compute networks list --format='json(name,autoCreateSubnetworks,routingConfig.routingMode)' --project $Project | ConvertFrom-Json }
        }
        $Results | Format-ToolOutput -Format $Format
    }
    'subnets' {
        $Results = switch ($Provider) {
            'aws'  { & aws ec2 describe-subnets --query 'Subnets[].[SubnetId,VpcId,AvailabilityZone,CidrBlock,AvailableIpAddressCount,MapPublicIpOnLaunch]' --output json $CommonArgs | ConvertFrom-Json | ForEach-Object { [PSCustomObject]@{ Id=$_[0]; VPC=$_[1]; AZ=$_[2]; CIDR=$_[3]; Available=$_[4]; Public=$_[5] } } }
            'azure' { & az network vnet subnet list --vnet-name $ArgsOnly[1] --resource-group $ArgsOnly[2] --output json | ConvertFrom-Json }
            'gcp'  { & gcloud compute networks subnets list --network $ArgsOnly[1] --format='json(name,region,ipCidrRange)' --project $Project | ConvertFrom-Json }
        }
        $Results | Format-ToolOutput -Format $Format
    }
    'sg' {
        $Results = switch ($Provider) {
            'aws'  { & aws ec2 describe-security-groups --query 'SecurityGroups[].[GroupId,GroupName,VpcId,Description]' --output json $CommonArgs | ConvertFrom-Json | ForEach-Object { [PSCustomObject]@{ Id=$_[0]; Name=$_[1]; VPC=$_[2]; Desc=$_[3] } } }
            'azure' { & az network nsg list --query '[].{Name:name, ResourceGroup:resourceGroup, Location:location}' --output json | ConvertFrom-Json }
            'gcp'  { & gcloud compute firewall-rules list --format='json(name,network,direction,allowed[].map().join(":"),denied[].map().join(":"))' --project $Project | ConvertFrom-Json }
        }
        $Results | Format-ToolOutput -Format $Format
    }
    default { Write-Host "$($C.Warn)[ERROR] Usage: net [vpcs|subnets|sg] ...$($C.Reset)" }
}