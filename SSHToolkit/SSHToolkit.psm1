
$global:SSHToolkitPath = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
Import-Module SharedToolkit -ErrorAction SilentlyContinue

function Register-Target {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,
        [string]$IP = "127.0.0.1",
        [string]$User = $env:USERNAME,
        [string]$Key = "$env:USERPROFILE\.ssh\id_local_test"
    )
    $ProfileFile = "$global:SSHToolkitPath\Profiles\$Name.json"
    if (-not (Test-Path (Split-Path $ProfileFile))) { New-Item -ItemType Directory -Path (Split-Path $ProfileFile) -Force | Out-Null }
    [PSCustomObject]@{IP = $IP ; User = $User ; Key = $Key } | ConvertTo-Json | Out-File $ProfileFile -Force
    New-Alias -Name $Name -Value Invoke-UniversalToolkitRouter -Description "Context Profile" -Scope Global -Force
    Export-ModuleMember -Alias $Name
    $C = if ($global:ToolColors) { $global:ToolColors } else { [PSCustomObject]@{} }
    Write-Host "[OK] Registered profile: $($C.Host)$Name$($C.Reset) - $User@$IP " -ForegroundColor Green
}

function Invoke-UniversalToolkitRouter {
    [CmdletBinding()]
    param([string]$Action, [Parameter(ValueFromRemainingArguments = $true)]$ForwardedArgs)
    $Inv = $MyInvocation.InvocationName
    if ($Inv -ne 'Invoke-UniversalToolkitRouter') { $ContextName = $Inv } else { $ContextName = $global:ToolContext }
    $C = if ($global:ToolColors) { $global:ToolColors } else { [PSCustomObject]@{} }
    $ProfileFile = "$global:SSHToolkitPath\Profiles\$ContextName.json"
    if (-not (Test-Path $ProfileFile)) { Write-Host "$($C.Crit)[ERROR] Profile registry missing for entity '$ContextName'$($C.Reset)" ; return }
    $Config = Get-Content $ProfileFile | ConvertFrom-Json
    $ForwardedArgs = @($ForwardedArgs)
    $global:ToolContext = $ContextName

    $Builtins = @('help', 'config', 'online', 'ssh')
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
        Invoke-SharedHelpSystem -Caller $ContextName -TargetTopic $Topic -ChildModulePath $global:SSHToolkitPath
        return
    }

    if ($Action -eq "config") {
        if ($ForwardedArgs -and $ForwardedArgs[0] -eq "view") {
            Write-Host "`n--- $($C.Sys)PROFILE MAPS:$($C.Reset) $($C.Host)[$ContextName]$($C.Reset) ---"
            Write-Host "  Target IP Binding Address  : $($C.Str)$($Config.IP)$($C.Reset)"
            Write-Host "  Target System Admin User   : $($C.Str)$($Config.User)$($C.Reset)"
            Write-Host "  Private Cryptographic Key  : $($C.File)$($Config.Key)$($C.Reset)"
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
            }
            else {
                Write-Host "$($C.Crit)[ERROR] Invalid key: use IP, User, or Key.$($C.Reset)"
            }
            return
        }
        Write-Host "$($C.Crit)[ERROR] Usage: $ContextName config view | config set [IP|User|Key] [value]$($C.Reset)"
        return
    }

    if ($Action -eq "online") {
        Write-Host "[*] Auditing network heartbeat to $($C.Str)$($Config.IP)$($C.Reset)..." -ForegroundColor Yellow
        if (Test-Connection -ComputerName $Config.IP -Count 1 -Quiet) { Write-Host "[PASS] Target is ONLINE." -ForegroundColor Green } else { Write-Host "[FAIL] Target is OFFLINE." -ForegroundColor Red }
        return
    }

    if ($Action -eq "ssh") {
        if (-not (Test-Connection -ComputerName $Config.IP -Count 1 -Quiet)) { Write-Host "[ABORT] Target unreachable." -ForegroundColor Yellow ; return }
        $ssCmd = "ssh -i " + $Config.Key + " " + $Config.User + "@" + $Config.IP
        Invoke-Expression $ssCmd
        return
    }

    Write-ToolCommand -ContextName $ContextName -Action $Action -Arguments $ForwardedArgs
    $ChildAction = "$global:SSHToolkitPath\Actions\$Action.ps1"
    if (Test-Path $ChildAction) { & $ChildAction -Config $Config -Arguments $ForwardedArgs ; return }

    $SharedFound = Invoke-SharedAsset -Type "Actions" -AssetName $Action -Config $Config -ForwardedArgs $ForwardedArgs
    if ($SharedFound) { return }

    $ChildListener = "$global:SSHToolkitPath\Listeners\$Action.ps1"
    if (Test-Path $ChildListener) { & $ChildListener -Config $Config -Arguments $ForwardedArgs ; return }

    $SharedListener = Invoke-SharedAsset -Type "Listeners" -AssetName $Action -Config $Config -ForwardedArgs $ForwardedArgs
    if ($SharedListener) { return }

    Write-Host "$($C.Crit)[ERROR] could not resolve '$Action'$($C.Reset)"
    Invoke-ToolEvent -Name "UnknownAction" -Data "$ContextName : $Action" -Config $Config
}

Get-ChildItem "$global:SSHToolkitPath\Profiles\*.json" -ErrorAction SilentlyContinue | ForEach-Object {
    New-Alias -Name $_.BaseName -Value Invoke-UniversalToolkitRouter -Force
    Export-ModuleMember -Alias $_.BaseName
}
New-Alias -Name "New-Target" -Value Register-Target -Force
Export-ModuleMember -Function * -Alias *
