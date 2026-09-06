
$global:SecToolkitPath = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
Import-Module SharedToolkit -ErrorAction SilentlyContinue

function Register-SecTarget {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][string]$Name, [string]$Scope = "local")
    $ProfileFile = "$global:SecToolkitPath\Profiles\$Name.json"
    if (-not (Test-Path (Split-Path $ProfileFile))) { New-Item -ItemType Directory -Path (Split-Path $ProfileFile) -Force | Out-Null }
    [PSCustomObject]@{Scope=$Scope} | ConvertTo-Json | Out-File $ProfileFile -Force
    New-Alias -Name $Name -Value Invoke-SecToolkitRouter -Description "Sec Target" -Scope Global -Force
    Export-ModuleMember -Alias $Name
    Write-Host "[OK] Registered sec target: $Name ($Scope)" -ForegroundColor Green
}

function Invoke-SecToolkitRouter {
    [CmdletBinding()]
    param([string]$Action, [Parameter(ValueFromRemainingArguments=$true)]$ForwardedArgs)
    $ContextName = $MyInvocation.InvocationName
    $C = if ($global:ToolColors) { $global:ToolColors } else { [PSCustomObject]@{} }
    $ProfileFile = "$global:SecToolkitPath\Profiles\$ContextName.json"
    if (-not (Test-Path $ProfileFile)) { Write-Host "$($C.Crit)[ERROR] Profile missing for '$ContextName'$($C.Reset)" ; return }
    $Config = Get-Content $ProfileFile | ConvertFrom-Json
    $ForwardedArgs = @($ForwardedArgs)
    $global:ToolContext = $ContextName
# Shared routing state: shared actions/listeners can resolve the toolkit that
# owns the active context instead of assuming SSHToolkit.
$global:CurrentToolkitPath = $global:SecToolkitPath
if ($Action) {
    $Action = Resolve-ToolkitActionName -Name $Action -ToolkitPath $global:SecToolkitPath
}

    if ($Action -eq 'help' -or $Action -eq '-h' -or $Action -eq '/?' -or -not $Action) {
        $Topic = if ($ForwardedArgs) { $ForwardedArgs -join ' ' } else { $null }
        Invoke-SharedHelpSystem -Caller $ContextName -TargetTopic $Topic -ChildModulePath $global:SecToolkitPath
        return
    }

    if ($Action -eq "config") {
        if ($ForwardedArgs -and $ForwardedArgs[0] -eq "view") {
            Write-Host "`n--- $($C.Sys)SEC PROFILE:$($C.Reset) $($C.Host)[$ContextName]$($C.Reset) ---"
            Write-Host "  Scope : $($C.Str)$($Config.Scope)$($C.Reset)"
            Write-Host "----------------------------`n"
            return
        }
        Write-Host "$($C.Crit)[ERROR] Usage: $ContextName config view$($C.Reset)"
        return
    }

    Write-ToolCommand -ContextName $ContextName -Action $Action -Arguments $ForwardedArgs
    $ChildAction = "$global:SecToolkitPath\Actions\$Action.ps1"
    if (Test-Path $ChildAction) { & $ChildAction -Config $Config -Arguments $ForwardedArgs ; return }

    $SharedFound = Invoke-SharedAsset -Type "Actions" -AssetName $Action -Config $Config -ForwardedArgs $ForwardedArgs
    if ($SharedFound) { return }

    Write-Host "$($C.Crit)[ERROR] could not resolve '$Action'$($C.Reset)"
}

Get-ChildItem "$global:SecToolkitPath\Profiles\*.json" -ErrorAction SilentlyContinue | ForEach-Object {
    New-Alias -Name $_.BaseName -Value Invoke-SecToolkitRouter -Force
    Export-ModuleMember -Alias $_.BaseName
}
New-Alias -Name "New-SecProfile" -Value Register-SecTarget -Force
Export-ModuleMember -Function * -Alias *
