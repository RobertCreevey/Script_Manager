$global:DockerToolkitPath = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
Import-Module SharedToolkit -ErrorAction SilentlyContinue

function Register-DockerProfile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$Name,
        [string]$Host = 'unix:///var/run/docker.sock',
        [string]$Context = 'default',
        [string]$Registry = '',
        [string]$Namespace = ''
    )
    $ProfileFile = "$global:DockerToolkitPath\Profiles\$Name.json"
    if (-not (Test-Path (Split-Path $ProfileFile))) { New-Item -ItemType Directory -Path (Split-Path $ProfileFile) -Force | Out-Null }
    [PSCustomObject]@{
        Host      = $Host
        Context   = $Context
        Registry  = $Registry
        Namespace = $Namespace
    } | ConvertTo-Json | Out-File $ProfileFile -Force
    New-Alias -Name $Name -Value Invoke-DockerToolkitRouter -Description "Docker Profile" -Scope Global -Force
    Export-ModuleMember -Alias $Name
    $C = if ($global:ToolColors) { $global:ToolColors } else { [PSCustomObject]@{} }
    Write-Host "[OK] Registered docker profile: $($C.Host)$Name$($C.Reset) - $Host" -ForegroundColor Green
}

function Invoke-DockerToolkitRouter {
    [CmdletBinding()]
    param([string]$Action, [Parameter(ValueFromRemainingArguments=$true)]$ForwardedArgs)
    $Inv = $MyInvocation.InvocationName
    if ($Inv -ne 'Invoke-DockerToolkitRouter') { $ContextName = $Inv } else { $ContextName = $global:ToolContext }
    $C = if ($global:ToolColors) { $global:ToolColors } else { [PSCustomObject]@{} }
    $ProfileFile = "$global:DockerToolkitPath\Profiles\$ContextName.json"
    if (-not (Test-Path $ProfileFile)) { Write-Host "$($C.Crit)[ERROR] Profile registry missing for '$ContextName'$($C.Reset)" ; return }
    $Config = Get-Content $ProfileFile | ConvertFrom-Json
    $ForwardedArgs = @($ForwardedArgs)
    $global:ToolContext = $ContextName
# Shared routing state: shared actions/listeners can resolve the toolkit that
# owns the active context instead of assuming SSHToolkit.
$global:CurrentToolkitPath = $global:DockerToolkitPath
if ($Action) {
    $Action = Resolve-ToolkitActionName -Name $Action -ToolkitPath $global:DockerToolkitPath
}

    $DockerHost = if ($Config.Host) { "-H $($Config.Host)" } else { "" }
    $DockerContext = if ($Config.Context -and $Config.Context -ne 'default') { "--context $($Config.Context)" } else { "" }

    $Builtins = @('help', 'config', 'online', 'context', 'login')
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
        Invoke-SharedHelpSystem -Caller $ContextName -TargetTopic $Topic -ChildModulePath $global:DockerToolkitPath
        return
    }

    if ($Action -eq "config") {
        if ($ForwardedArgs -and $ForwardedArgs[0] -eq "view") {
            Write-Host "`n--- $($C.Sys)DOCKER PROFILE:$($C.Reset) $($C.Host)[$ContextName]$($C.Reset) ---"
            Write-Host "  Host      : $($C.Str)$($Config.Host)$($C.Reset)"
            Write-Host "  Context   : $($C.Str)$($Config.Context)$($C.Reset)"
            Write-Host "  Registry  : $($C.Str)$($Config.Registry)$($C.Reset)"
            Write-Host "  Namespace : $($C.Str)$($Config.Namespace)$($C.Reset)"
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
                Write-Host "$($C.Crit)[ERROR] Invalid key: Host, Context, Registry, Namespace.$($C.Reset)"
            }
            return
        }
        Write-Host "$($C.Crit)[ERROR] Usage: $ContextName config view | config set [Host|Context|Registry|Namespace] [value]$($C.Reset)"
        return
    }

    if ($Action -eq "online") {
        $Out = & docker $DockerHost $DockerContext version --format '{{.Server.Version}}' 2>$null
        if ($Out) { Write-Host "[PASS] Docker daemon reachable (v$Out)." -ForegroundColor Green } else { Write-Host "[FAIL] Docker daemon not reachable." -ForegroundColor Red }
        return
    }

    if ($Action -eq "context") {
        $Sub = if ($ForwardedArgs[0]) { $ForwardedArgs[0] } else { 'ls' }
        switch ($Sub) {
            'ls'  { & docker context ls }
            'use' { & docker context use $ForwardedArgs[1] }
            default { Write-Host "$($C.Crit)[ERROR] Usage: context [ls|use <name>]$($C.Reset)" }
        }
        return
    }

    if ($Action -eq "login") {
        $Registry = if ($ForwardedArgs[0]) { $ForwardedArgs[0] } else { $Config.Registry }
        if (-not $Registry) { Write-Host "$($C.Crit)[ERROR] Usage: login <registry> or set config Registry$($C.Reset)" ; return }
        & docker $DockerHost $DockerContext login $Registry
        return
    }

    Write-ToolCommand -ContextName $ContextName -Action $Action -Arguments $ForwardedArgs
    $ChildAction = "$global:DockerToolkitPath\Actions\$Action.ps1"
    if (Test-Path $ChildAction) { & $ChildAction -Config $Config -Arguments $ForwardedArgs ; return }

    $SharedFound = Invoke-SharedAsset -Type "Actions" -AssetName $Action -Config $Config -ForwardedArgs $ForwardedArgs
    if ($SharedFound) { return }

    $ChildListener = "$global:DockerToolkitPath\Listeners\$Action.ps1"
    if (Test-Path $ChildListener) { & $ChildListener -Config $Config -Arguments $ForwardedArgs ; return }

    $SharedListener = Invoke-SharedAsset -Type "Listeners" -AssetName $Action -Config $Config -ForwardedArgs $ForwardedArgs
    if ($SharedListener) { return }

    Write-Host "$($C.Crit)[ERROR] could not resolve '$Action'$($C.Reset)"
    Invoke-ToolEvent -Name "UnknownAction" -Data "$ContextName : $Action" -Config $Config
}

Get-ChildItem "$global:DockerToolkitPath\Profiles\*.json" -ErrorAction SilentlyContinue | ForEach-Object {
    New-Alias -Name $_.BaseName -Value Invoke-DockerToolkitRouter -Force
    Export-ModuleMember -Alias $_.BaseName
}
New-Alias -Name "New-DockerProfile" -Value Register-DockerProfile -Force
Export-ModuleMember -Function * -Alias *