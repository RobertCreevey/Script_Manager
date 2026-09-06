$global:GitToolkitPath = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
Import-Module SharedToolkit -ErrorAction SilentlyContinue

function Register-GitProfile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$Name,
        [string]$Path = "$env:USERPROFILE\Projects",
        [string]$User = $env:USERNAME,
        [string]$Email = "$env:USERNAME@localhost",
        [string]$Remote = ''
    )
    $ProfileFile = "$global:GitToolkitPath\Profiles\$Name.json"
    if (-not (Test-Path (Split-Path $ProfileFile))) { New-Item -ItemType Directory -Path (Split-Path $ProfileFile) -Force | Out-Null }
    [PSCustomObject]@{
        Path   = $Path
        User   = $User
        Email  = $Email
        Remote = $Remote
    } | ConvertTo-Json | Out-File $ProfileFile -Force
    New-Alias -Name $Name -Value Invoke-GitToolkitRouter -Description "Git Profile" -Scope Global -Force
    Export-ModuleMember -Alias $Name
    $C = if ($global:ToolColors) { $global:ToolColors } else { [PSCustomObject]@{} }
    Write-Host "[OK] Registered git profile: $($C.Host)$Name$($C.Reset) - $Path" -ForegroundColor Green
}

function Invoke-GitToolkitRouter {
    [CmdletBinding()]
    param([string]$Action, [Parameter(ValueFromRemainingArguments=$true)]$ForwardedArgs)
    $Inv = $MyInvocation.InvocationName
    if ($Inv -ne 'Invoke-GitToolkitRouter') { $ContextName = $Inv } else { $ContextName = $global:ToolContext }
    $C = if ($global:ToolColors) { $global:ToolColors } else { [PSCustomObject]@{} }
    $ProfileFile = "$global:GitToolkitPath\Profiles\$ContextName.json"
    if (-not (Test-Path $ProfileFile)) { Write-Host "$($C.Crit)[ERROR] Profile registry missing for '$ContextName'$($C.Reset)" ; return }
    $Config = Get-Content $ProfileFile | ConvertFrom-Json
    $ForwardedArgs = @($ForwardedArgs)
    $global:ToolContext = $ContextName
# Shared routing state: shared actions/listeners can resolve the toolkit that
# owns the active context instead of assuming SSHToolkit.
$global:CurrentToolkitPath = $global:GitToolkitPath
if ($Action) {
    $Action = Resolve-ToolkitActionName -Name $Action -ToolkitPath $global:GitToolkitPath
}

    $Builtins = @('help', 'config', 'online', 'init', 'clone')
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
        Invoke-SharedHelpSystem -Caller $ContextName -TargetTopic $Topic -ChildModulePath $global:GitToolkitPath
        return
    }

    if ($Action -eq "config") {
        if ($ForwardedArgs -and $ForwardedArgs[0] -eq "view") {
            Write-Host "`n--- $($C.Sys)GIT PROFILE:$($C.Reset) $($C.Host)[$ContextName]$($C.Reset) ---"
            Write-Host "  Path   : $($C.Str)$($Config.Path)$($C.Reset)"
            Write-Host "  User   : $($C.Str)$($Config.User)$($C.Reset)"
            Write-Host "  Email  : $($C.Str)$($Config.Email)$($C.Reset)"
            Write-Host "  Remote : $($C.Str)$($Config.Remote)$($C.Reset)"
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
                Write-Host "$($C.Crit)[ERROR] Invalid key: Path, User, Email, Remote.$($C.Reset)"
            }
            return
        }
        Write-Host "$($C.Crit)[ERROR] Usage: $ContextName config view | config set [Path|User|Email|Remote] [value]$($C.Reset)"
        return
    }

    if ($Action -eq "online") {
        Write-Host "[*] Checking git availability..." -ForegroundColor Yellow
        $Git = Get-Command git -ErrorAction SilentlyContinue
        if ($Git) { Write-Host "[PASS] Git found: $($Git.Source)" -ForegroundColor Green } else { Write-Host "[FAIL] Git not found in PATH" -ForegroundColor Red }
        return
    }

    if ($Action -eq "init") {
        $RepoPath = if ($ForwardedArgs[0]) { $ForwardedArgs[0] } else { $Config.Path }
        if (-not (Test-Path $RepoPath)) { New-Item -ItemType Directory -Path $RepoPath -Force | Out-Null }
        Set-Location $RepoPath
        & git init
        & git config user.name $Config.User
        & git config user.email $Config.Email
        Write-Host "[OK] Initialized git repo at $RepoPath" -ForegroundColor Green
        return
    }

    if ($Action -eq "clone") {
        if (-not $ForwardedArgs[0]) { Write-Host "$($C.Crit)[ERROR] Usage: clone <url> [path]$($C.Reset)" ; return }
        $Url = $ForwardedArgs[0]
        $Path = if ($ForwardedArgs[1]) { $ForwardedArgs[1] } else { $Config.Path }
        & git clone $Url $Path
        return
    }

    Write-ToolCommand -ContextName $ContextName -Action $Action -Arguments $ForwardedArgs
    $ChildAction = "$global:GitToolkitPath\Actions\$Action.ps1"
    if (Test-Path $ChildAction) { & $ChildAction -Config $Config -Arguments $ForwardedArgs ; return }

    $SharedFound = Invoke-SharedAsset -Type "Actions" -AssetName $Action -Config $Config -ForwardedArgs $ForwardedArgs
    if ($SharedFound) { return }

    $ChildListener = "$global:GitToolkitPath\Listeners\$Action.ps1"
    if (Test-Path $ChildListener) { & $ChildListener -Config $Config -Arguments $ForwardedArgs ; return }

    $SharedListener = Invoke-SharedAsset -Type "Listeners" -AssetName $Action -Config $Config -ForwardedArgs $ForwardedArgs
    if ($SharedListener) { return }

    Write-Host "$($C.Crit)[ERROR] could not resolve '$Action'$($C.Reset)"
    Invoke-ToolEvent -Name "UnknownAction" -Data "$ContextName : $Action" -Config $Config
}

Get-ChildItem "$global:GitToolkitPath\Profiles\*.json" -ErrorAction SilentlyContinue | ForEach-Object {
    New-Alias -Name $_.BaseName -Value Invoke-GitToolkitRouter -Force
    Export-ModuleMember -Alias $_.BaseName
}
New-Alias -Name "New-GitProfile" -Value Register-GitProfile -Force
Export-ModuleMember -Function * -Alias *