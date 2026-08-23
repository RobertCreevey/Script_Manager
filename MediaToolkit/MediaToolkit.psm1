
$global:MediaToolkitPath = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
Import-Module SharedToolkit -ErrorAction SilentlyContinue

function Register-MediaTarget {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][string]$Name, [string]$DefaultDevice = "")
    $ProfileFile = "$global:MediaToolkitPath\Profiles\$Name.json"
    if (-not (Test-Path (Split-Path $ProfileFile))) { New-Item -ItemType Directory -Path (Split-Path $ProfileFile) -Force | Out-Null }
    [PSCustomObject]@{DefaultDevice=$DefaultDevice} | ConvertTo-Json | Out-File $ProfileFile -Force
    New-Alias -Name $Name -Value Invoke-MediaToolkitRouter -Description "Media Target" -Scope Global -Force
    Export-ModuleMember -Alias $Name
    Write-Host "[OK] Registered media target: $Name" -ForegroundColor Green
}

function Invoke-MediaToolkitRouter {
    [CmdletBinding()]
    param([string]$Action, [Parameter(ValueFromRemainingArguments=$true)]$ForwardedArgs)
    $ContextName = $MyInvocation.InvocationName
    $C = if ($global:ToolColors) { $global:ToolColors } else { [PSCustomObject]@{} }
    $ProfileFile = "$global:MediaToolkitPath\Profiles\$ContextName.json"
    if (-not (Test-Path $ProfileFile)) { Write-Host "$($C.Warn)[ERROR] Profile missing for '$ContextName'$($C.Reset)" ; return }
    $Config = Get-Content $ProfileFile | ConvertFrom-Json
    $ForwardedArgs = @($ForwardedArgs)
    $global:ToolContext = $ContextName

    if ($Action -eq 'help' -or $Action -eq '-h' -or $Action -eq '/?' -or -not $Action) {
        $Topic = if ($ForwardedArgs) { $ForwardedArgs -join ' ' } else { $null }
        Invoke-SharedHelpSystem -Caller $ContextName -TargetTopic $Topic -ChildModulePath $global:MediaToolkitPath
        return
    }

    if ($Action -eq "config") {
        if ($ForwardedArgs -and $ForwardedArgs[0] -eq "view") {
            Write-Host "`n--- $($C.Sys)MEDIA PROFILE:$($C.Reset) $($C.Host)[$ContextName]$($C.Reset) ---"
            Write-Host "  DefaultDevice : $($C.Str)$($Config.DefaultDevice)$($C.Reset)"
            Write-Host "----------------------------`n"
            return
        }
        Write-Host "$($C.Warn)[ERROR] Usage: $ContextName config view$($C.Reset)"
        return
    }

    $ChildAction = "$global:MediaToolkitPath\Actions\$Action.ps1"
    if (Test-Path $ChildAction) { & $ChildAction -Config $Config -Args $ForwardedArgs ; return }

    $SharedFound = Invoke-SharedAsset -Type "Actions" -AssetName $Action -Config $Config -ForwardedArgs $ForwardedArgs
    if ($SharedFound) { return }

    Write-Host "$($C.Warn)[ERROR] could not resolve '$Action'$($C.Reset)"
}

Get-ChildItem "$global:MediaToolkitPath\Profiles\*.json" -ErrorAction SilentlyContinue | ForEach-Object {
    New-Alias -Name $_.BaseName -Value Invoke-MediaToolkitRouter -Force
    Export-ModuleMember -Alias $_.BaseName
}
New-Alias -Name "newmedia" -Value Register-MediaTarget -Force
Export-ModuleMember -Function * -Alias *
