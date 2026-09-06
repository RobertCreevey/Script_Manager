
$global:FileToolkitPath = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
Import-Module SharedToolkit -ErrorAction SilentlyContinue

function Register-FileTarget {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][string]$Name, [string]$Root = $env:USERPROFILE)
    $ProfileFile = "$global:FileToolkitPath\Profiles\$Name.json"
    if (-not (Test-Path (Split-Path $ProfileFile))) { New-Item -ItemType Directory -Path (Split-Path $ProfileFile) -Force | Out-Null }
    [PSCustomObject]@{Root=$Root} | ConvertTo-Json | Out-File $ProfileFile -Force
    New-Alias -Name $Name -Value Invoke-FileToolkitRouter -Description "File Target" -Scope Global -Force
    Export-ModuleMember -Alias $Name
    Write-Host "[OK] Registered file target: $Name ($Root)" -ForegroundColor Green
}

function Invoke-FileToolkitRouter {
    [CmdletBinding()]
    param([string]$Action, [Parameter(ValueFromRemainingArguments=$true)]$ForwardedArgs)
    $ContextName = $MyInvocation.InvocationName
    $C = if ($global:ToolColors) { $global:ToolColors } else { [PSCustomObject]@{} }
    $ProfileFile = "$global:FileToolkitPath\Profiles\$ContextName.json"
    if (-not (Test-Path $ProfileFile)) { Write-Host "$($C.Crit)[ERROR] Profile missing for '$ContextName'$($C.Reset)" ; return }
    $Config = Get-Content $ProfileFile | ConvertFrom-Json
    $ForwardedArgs = @($ForwardedArgs)
    $global:ToolContext = $ContextName

    if ($Action -eq 'help' -or $Action -eq '-h' -or $Action -eq '/?' -or -not $Action) {
        $Topic = if ($ForwardedArgs) { $ForwardedArgs -join ' ' } else { $null }
        Invoke-SharedHelpSystem -Caller $ContextName -TargetTopic $Topic -ChildModulePath $global:FileToolkitPath
        return
    }

    if ($Action -eq "config") {
        if ($ForwardedArgs -and $ForwardedArgs[0] -eq "view") {
            Write-Host "`n--- $($C.Sys)FILE PROFILE:$($C.Reset) $($C.Host)[$ContextName]$($C.Reset) ---"
            Write-Host "  Root : $($C.Str)$($Config.Root)$($C.Reset)"
            Write-Host "----------------------------`n"
            return
        }
        Write-Host "$($C.Crit)[ERROR] Usage: $ContextName config view$($C.Reset)"
        return
    }

    Write-ToolCommand -ContextName $ContextName -Action $Action -Arguments $ForwardedArgs
    $ChildAction = "$global:FileToolkitPath\Actions\$Action.ps1"
    if (Test-Path $ChildAction) { & $ChildAction -Config $Config -Args $ForwardedArgs ; return }

    $SharedFound = Invoke-SharedAsset -Type "Actions" -AssetName $Action -Config $Config -ForwardedArgs $ForwardedArgs
    if ($SharedFound) { return }

    Write-Host "$($C.Crit)[ERROR] could not resolve '$Action'$($C.Reset)"
}

Get-ChildItem "$global:FileToolkitPath\Profiles\*.json" -ErrorAction SilentlyContinue | ForEach-Object {
    New-Alias -Name $_.BaseName -Value Invoke-FileToolkitRouter -Force
    Export-ModuleMember -Alias $_.BaseName
}
New-Alias -Name "New-FileProfile" -Value Register-FileTarget -Force
Export-ModuleMember -Function * -Alias *
