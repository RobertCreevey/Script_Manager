$global:CloudToolkitPath = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
Import-Module SharedToolkit -ErrorAction SilentlyContinue

function Register-CloudProfile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$Name,
        [ValidateSet('aws','azure','gcp')][string]$Provider = 'aws',
        [string]$Region = 'us-east-1',
        [string]$Profile = 'default',
        [string]$Project = '',
        [string]$Subscription = ''
    )
    $ProfileFile = "$global:CloudToolkitPath\Profiles\$Name.json"
    if (-not (Test-Path (Split-Path $ProfileFile))) { New-Item -ItemType Directory -Path (Split-Path $ProfileFile) -Force | Out-Null }
    [PSCustomObject]@{
        Provider = $Provider
        Region   = $Region
        Profile  = $Profile
        Project  = $Project
        Subscription = $Subscription
    } | ConvertTo-Json | Out-File $ProfileFile -Force
    New-Alias -Name $Name -Value Invoke-CloudToolkitRouter -Description "Cloud Profile" -Scope Global -Force
    Export-ModuleMember -Alias $Name
    $C = if ($global:ToolColors) { $global:ToolColors } else { [PSCustomObject]@{} }
    Write-Host "[OK] Registered cloud profile: $($C.Host)$Name$($C.Reset) - $Provider / $Region" -ForegroundColor Green
}

function Invoke-CloudToolkitRouter {
    [CmdletBinding()]
    param([string]$Action, [Parameter(ValueFromRemainingArguments=$true)]$ForwardedArgs)
    $Inv = $MyInvocation.InvocationName
    if ($Inv -ne 'Invoke-CloudToolkitRouter') { $ContextName = $Inv } else { $ContextName = $global:ToolContext }
    $C = if ($global:ToolColors) { $global:ToolColors } else { [PSCustomObject]@{} }
    $ProfileFile = "$global:CloudToolkitPath\Profiles\$ContextName.json"
    if (-not (Test-Path $ProfileFile)) { Write-Host "$($C.Crit)[ERROR] Profile registry missing for '$ContextName'$($C.Reset)" ; return }
    $Config = Get-Content $ProfileFile | ConvertFrom-Json
    $ForwardedArgs = @($ForwardedArgs)
    $global:ToolContext = $ContextName
# Shared routing state: shared actions/listeners can resolve the toolkit that
# owns the active context instead of assuming SSHToolkit.
$global:CurrentToolkitPath = $global:CloudToolkitPath
if ($Action) {
    $Action = Resolve-ToolkitActionName -Name $Action -ToolkitPath $global:CloudToolkitPath
}

    $Builtins = @('help', 'config', 'online', 'auth', 'regions')
    if ($Action -and $Action -notin $Builtins) {
        $AliasFile = "$global:SharedToolkitPath\Aliases\$Action.json"
        if (Test-Path $AliasFile) {
            $AliasCmd = (Get-Content $AliasFile | ConvertFrom-Json).Command
            $Parts = $AliasCmd -split '\s+'
            $Action = $Parts[0]
            $ForwardedArgs = @($Parts[1..($Parts.Length - 1)]) + $ForwardedArgs
            Invoke-ToolEvent -Name "AliasResolved" -Data "$ContextName -> $AliasCmd" -Config $Config
        }
    }

    if ($Action -eq 'help' -or $Action -eq '-h' -or $Action -eq '/?' -or -not $Action) {
        $Topic = if ($ForwardedArgs) { $ForwardedArgs -join ' ' } else { $null }
        Invoke-SharedHelpSystem -Caller $ContextName -TargetTopic $Topic -ChildModulePath $global:CloudToolkitPath
        return
    }

    if ($Action -eq "config") {
        if ($ForwardedArgs -and $ForwardedArgs[0] -eq "view") {
            Write-Host "`n--- $($C.Sys)CLOUD PROFILE:$($C.Reset) $($C.Host)[$ContextName]$($C.Reset) ---"
            Write-Host "  Provider     : $($C.Str)$($Config.Provider)$($C.Reset)"
            Write-Host "  Region       : $($C.Str)$($Config.Region)$($C.Reset)"
            Write-Host "  CLI Profile  : $($C.Str)$($Config.Profile)$($C.Reset)"
            if ($Config.Project)     { Write-Host "  Project/Sub  : $($C.Str)$($Config.Project)$($Config.Subscription)$($C.Reset)" }
            Write-Host "-------------------------------------------`n"
            return
        }
        if ($ForwardedArgs -and $ForwardedArgs[0] -eq "set" -and $ForwardedArgs[1]) {
            $K = $ForwardedArgs[1]
            $V = (($ForwardedArgs | Select-Object -Skip 2) -join " ").Trim()
            if ($Config.PSObject.Properties[$K]) {
                $Config.$K = $V
                $Config | ConvertTo-Json | Out-File $ProfileFile -Force
                Write-Host "[OK] Saved $($C.Param)$K$($C.Reset) = $($C.Str)$V$($C.Reset)" -ForegroundColor Green
            } else {
                Write-Host "$($C.Crit)[ERROR] Invalid key: Provider, Region, Profile, Project, Subscription.$($C.Reset)"
            }
            return
        }
        Write-Host "$($C.Crit)[ERROR] Usage: $ContextName config view | config set [Provider|Region|Profile|Project|Subscription] [value]$($C.Reset)"
        return
    }

    if ($Action -eq "online") {
        $Provider = $Config.Provider
        $OK = switch ($Provider) {
            'aws'     { $null = Get-Command aws -ErrorAction SilentlyContinue; & aws sts get-caller-identity -ErrorAction SilentlyContinue; $LASTEXITCODE -eq 0 }
            'azure'   { $null = Get-Command az -ErrorAction SilentlyContinue; & az account show -ErrorAction SilentlyContinue; $LASTEXITCODE -eq 0 }
            'gcp'     { $null = Get-Command gcloud -ErrorAction SilentlyContinue; & gcloud auth list --filter=status:ACTIVE --format='value(account)' -ErrorAction SilentlyContinue; $LASTEXITCODE -eq 0 }
            default   { $false }
        }
        Write-Host "[*] Checking $Provider auth..." -ForegroundColor Yellow
        if ($OK) { Write-Host "[PASS] Authenticated to $Provider." -ForegroundColor Green } else { Write-Host "[FAIL] Not authenticated to $Provider." -ForegroundColor Red }
        return
    }

    if ($Action -eq "auth") {
        $Provider = $Config.Provider
        $Sub = if ($ForwardedArgs[0]) { $ForwardedArgs[0] } else { 'login' }
        switch ($Provider) {
            'aws'  { & aws configure $Sub @($ForwardedArgs[1..($ForwardedArgs.Count-1)]) }
            'azure' { & az login $Sub @($ForwardedArgs[1..($ForwardedArgs.Count-1)]) }
            'gcp'  { & gcloud auth $Sub @($ForwardedArgs[1..($ForwardedArgs.Count-1)]) }
        }
        return
    }

    if ($Action -eq "regions") {
        $Provider = $Config.Provider
        switch ($Provider) {
            'aws'  { & aws ec2 describe-regions --query 'Regions[].RegionName' --output table }
            'azure' { & az account list-locations --output table }
            'gcp'  { & gcloud compute regions list --format='table(name,status)' }
        }
        return
    }

    Write-ToolCommand -ContextName $ContextName -Action $Action -Arguments $ForwardedArgs
    $ChildAction = "$global:CloudToolkitPath\Actions\$Action.ps1"
    if (Test-Path $ChildAction) { & $ChildAction -Config $Config -Arguments $ForwardedArgs ; return }

    $SharedFound = Invoke-SharedAsset -Type "Actions" -AssetName $Action -Config $Config -ForwardedArgs $ForwardedArgs
    if ($SharedFound) { return }

    $ChildListener = "$global:CloudToolkitPath\Listeners\$Action.ps1"
    if (Test-Path $ChildListener) { & $ChildListener -Config $Config -Arguments $ForwardedArgs ; return }

    $SharedListener = Invoke-SharedAsset -Type "Listeners" -AssetName $Action -Config $Config -ForwardedArgs $ForwardedArgs
    if ($SharedListener) { return }

    Write-Host "$($C.Crit)[ERROR] could not resolve '$Action'$($C.Reset)"
    Invoke-ToolEvent -Name "UnknownAction" -Data "$ContextName : $Action" -Config $Config
}

Get-ChildItem "$global:CloudToolkitPath\Profiles\*.json" -ErrorAction SilentlyContinue | ForEach-Object {
    New-Alias -Name $_.BaseName -Value Invoke-CloudToolkitRouter -Force
    Export-ModuleMember -Alias $_.BaseName
}
New-Alias -Name "New-CloudProfile" -Value Register-CloudProfile -Force
Export-ModuleMember -Function * -Alias *