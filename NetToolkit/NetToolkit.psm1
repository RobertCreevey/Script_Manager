
$global:NetToolkitPath = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
Import-Module SharedToolkit -ErrorAction SilentlyContinue

function Register-NetTarget {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$Name,
        [string]$IP = "127.0.0.1",
        [string]$MAC = "",
        [string]$Broadcast = ""
    )
    $ProfileFile = "$global:NetToolkitPath\Profiles\$Name.json"
    if (-not (Test-Path (Split-Path $ProfileFile))) { New-Item -ItemType Directory -Path (Split-Path $ProfileFile) -Force | Out-Null }
    [PSCustomObject]@{IP=$IP; MAC=$MAC; Broadcast=$Broadcast} | ConvertTo-Json | Out-File $ProfileFile -Force
    New-Alias -Name $Name -Value Invoke-NetToolkitRouter -Description "Net Target" -Scope Global -Force
    Export-ModuleMember -Alias $Name
    Write-Host "[OK] Registered net target: $Name - $IP" -ForegroundColor Green
}

function Invoke-NetToolkitRouter {
    [CmdletBinding()]
    param([string]$Action, [Parameter(ValueFromRemainingArguments=$true)]$ForwardedArgs)
    $ContextName = $MyInvocation.InvocationName
    $C = if ($global:ToolColors) { $global:ToolColors } else { [PSCustomObject]@{} }
    $ProfileFile = "$global:NetToolkitPath\Profiles\$ContextName.json"
    if (-not (Test-Path $ProfileFile)) { Write-Host "$($C.Warn)[ERROR] Profile missing for '$ContextName'$($C.Reset)" ; return }
    $Config = Get-Content $ProfileFile | ConvertFrom-Json
    $ForwardedArgs = @($ForwardedArgs)
    $global:ToolContext = $ContextName

    if ($Action -eq 'help' -or $Action -eq '-h' -or $Action -eq '/?' -or -not $Action) {
        $Topic = if ($ForwardedArgs) { $ForwardedArgs -join ' ' } else { $null }
        Invoke-SharedHelpSystem -Caller $ContextName -TargetTopic $Topic -ChildModulePath $global:NetToolkitPath
        return
    }

    if ($Action -eq "config") {
        if ($ForwardedArgs -and $ForwardedArgs[0] -eq "view") {
            Write-Host "`n--- $($C.Sys)NET PROFILE:$($C.Reset) $($C.Host)[$ContextName]$($C.Reset) ---"
            Write-Host "  IP         : $($C.Str)$($Config.IP)$($C.Reset)"
            Write-Host "  MAC        : $($C.Str)$($Config.MAC)$($C.Reset)"
            Write-Host "  Broadcast  : $($C.Str)$($Config.Broadcast)$($C.Reset)"
            Write-Host "----------------------------`n"
            return
        }
        if ($ForwardedArgs -and $ForwardedArgs[0] -eq "set" -and $ForwardedArgs[1]) {
            $K = $ForwardedArgs[1]; $V = ($ForwardedArgs[2..($ForwardedArgs.Length-1)] -join " ").Trim()
            if ($Config.PSObject.Properties[$K]) { $Config.$K = $V; $Config | ConvertTo-Json | Out-File $ProfileFile -Force; Write-Host "[OK] $K = $V" -ForegroundColor Green }
            else { Write-Host "$($C.Warn)[ERROR] Invalid key: IP, MAC, Broadcast.$($C.Reset)" }
            return
        }
        Write-Host "$($C.Warn)[ERROR] Usage: $ContextName config view | config set [IP|MAC|Broadcast] [value]$($C.Reset)"
        return
    }

    $ChildAction = "$global:NetToolkitPath\Actions\$Action.ps1"
    if (Test-Path $ChildAction) { & $ChildAction -Config $Config -Args $ForwardedArgs ; return }

    $SharedFound = Invoke-SharedAsset -Type "Actions" -AssetName $Action -Config $Config -ForwardedArgs $ForwardedArgs
    if ($SharedFound) { return }

    $ChildListener = "$global:NetToolkitPath\Listeners\$Action.ps1"
    if (Test-Path $ChildListener) { & $ChildListener -Config $Config -Args $ForwardedArgs ; return }

    $SharedListener = Invoke-SharedAsset -Type "Listeners" -AssetName $Action -Config $Config -ForwardedArgs $ForwardedArgs
    if ($SharedListener) { return }

    Write-Host "$($C.Warn)[ERROR] could not resolve '$Action'$($C.Reset)"
}

Get-ChildItem "$global:NetToolkitPath\Profiles\*.json" -ErrorAction SilentlyContinue | ForEach-Object {
    New-Alias -Name $_.BaseName -Value Invoke-NetToolkitRouter -Force
    Export-ModuleMember -Alias $_.BaseName
}
New-Alias -Name "newnet" -Value Register-NetTarget -Force
Export-ModuleMember -Function * -Alias *
