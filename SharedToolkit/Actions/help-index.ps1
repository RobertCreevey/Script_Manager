# Type: Action
# Description: Full hierarchical help index - all toolkits, actions, parameters, switches, listeners, chains, aliases.
param($Config, [array]$Arguments)
$C = if ($global:ToolColors) { $global:ToolColors } else { [PSCustomObject]@{}}
$ArgsOnly = @($Arguments | Where-Object { $_ -notin @("-Force", "-f", "-json", "-csv", "-raw", "-table", "-h", "-?") })
$Format = "table"
if ($Arguments -contains '-json') { $Format = 'json' } elseif ($Arguments -contains '-csv') { $Format = 'csv' } elseif ($Arguments -contains '-raw') { $Format = 'raw' }
$Topic = if ($ArgsOnly[0]) { $ArgsOnly[0] } else { 'index' }
$SubTopic = if ($ArgsOnly[1]) { $ArgsOnly[1] } else { $null }

function Load-ToolkitManifest {
    param([string]$ToolkitPath)
    $ManifestFile = "$ToolkitPath\toolkit.json"
    if (Test-Path $ManifestFile) {
        Get-Content $ManifestFile -Raw | ConvertFrom-Json
    } else {
        return $null
    }
}

function Get-AllToolkits {
    $ModulesPath = "$env:USERPROFILE\Documents\PowerShell\Modules"
    $Toolkits = @()
    if (Test-Path $ModulesPath) {
        Get-ChildItem $ModulesPath -Directory | Where-Object { Test-Path "$($_.FullName)\$($_.Name).psm1" } | ForEach-Object {
            $Manifest = Load-ToolkitManifest $_.FullName
            $ActionNames = if ($Manifest.actions) { $Manifest.actions.PSObject.Properties.Name } else { @() }
            $ListenerNames = if ($Manifest.listeners) { $Manifest.listeners.PSObject.Properties.Name } else { @() }
            $BuiltinNames = if ($Manifest.builtins) { $Manifest.builtins.PSObject.Properties.Name } else { @() }
            $Toolkits += [PSCustomObject]@{
                Name = $_.Name
                Path = $_.FullName
                Manifest = $Manifest
                Actions = $ActionNames
                Listeners = $ListenerNames
                Builtins = $BuiltinNames
            }
        }
    }
    return $Toolkits
}

switch ($Topic) {
    'index' {
        Write-Host ""
        Write-Host "===== TOOLKIT ECOSYSTEM HELP INDEX =====" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Usage: <profile> help-index <topic> [subtopic]" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Topics:" -ForegroundColor Yellow
        Write-Host "  toolkits        - List all installed toolkits with summaries"
        Write-Host "  actions         - All actions across all toolkits (with aliases)"
        Write-Host "  listeners       - All listeners across all toolkits"
        Write-Host "  builtins        - Built-in commands per toolkit"
        Write-Host "  switches        - Global and action-specific switches"
        Write-Host "  parameters      - Parameters for a specific action"
        Write-Host "  chains          - Chain syntax and management"
        Write-Host "  aliases         - Alias system and cross-toolkit dispatch"
        Write-Host "  profiles        - Profile management commands"
        Write-Host "  dispatch        - Cross-toolkit action dispatch"
        Write-Host "  visual          - Visual/interactive methods (play, popup, msg)"
        Write-Host "  troubleshooting - Common issues and solutions"
        Write-Host ""
    }
    'toolkits' {
        $All = Get-AllToolkits
        Write-Host ""
        Write-Host "===== INSTALLED TOOLKITS =====" -ForegroundColor Cyan
        foreach ($Tk in $All) {
            $M = $Tk.Manifest
            Write-Host ""
            Write-Host "$($C.Action)$($Tk.Name)$($C.Reset) v$($C.Str)$($M.version)$($C.Reset)" -ForegroundColor White
            Write-Host "  $($C.Str)$($M.description)$($C.Reset)"
            Write-Host "  $($C.Param)Actions:$($C.Reset) $($Tk.Actions.Count)  $($C.List)Listeners:$($C.Reset) $($Tk.Listeners.Count)  $($C.Host)Builtins:$($C.Reset) $($Tk.Builtins.Count)"
            if ($Tk.Actions) { Write-Host "    $($Tk.Actions -join ', ')" }
        }
        Write-Host ""
    }
    'actions' {
        $All = Get-AllToolkits
        Write-Host ""
        Write-Host "===== ALL ACTIONS (canonical + aliases) =====" -ForegroundColor Cyan
        foreach ($Tk in $All) {
            $M = $Tk.Manifest
            if ($M.actions) {
                Write-Host ""
                Write-Host "$($C.Host)[$($Tk.Name)]$($C.Reset)" -ForegroundColor Magenta
                foreach ($Act in $M.actions.PSObject.Properties.Name) {
                    $Aliases = $M.actions.$Act -join ', '
                    Write-Host "  $($C.Action)$Act$($C.Reset)  [$Aliases]"
                }
            }
        }
        Write-Host ""
    }
    'listeners' {
        $All = Get-AllToolkits
        Write-Host ""
        Write-Host "===== ALL LISTENERS (canonical + aliases) =====" -ForegroundColor Cyan
        foreach ($Tk in $All) {
            $M = $Tk.Manifest
            if ($M.listeners) {
                Write-Host ""
                Write-Host "$($C.Host)[$($Tk.Name)]$($C.Reset)" -ForegroundColor Magenta
                foreach ($Lis in $M.listeners.PSObject.Properties.Name) {
                    $Aliases = $M.listeners.$Lis -join ', '
                    Write-Host "  $($C.List)$Lis$($C.Reset)  [$Aliases]"
                }
            }
        }
        Write-Host ""
    }
    'builtins' {
        $All = Get-AllToolkits
        Write-Host ""
        Write-Host "===== BUILT-IN COMMANDS PER TOOLKIT =====" -ForegroundColor Cyan
        foreach ($Tk in $All) {
            $M = $Tk.Manifest
            if ($M.builtins) {
                Write-Host ""
                Write-Host "$($C.Host)[$($Tk.Name)]$($C.Reset)" -ForegroundColor Magenta
                foreach ($Bin in $M.builtins.PSObject.Properties.Name) {
                    $Aliases = $M.builtins.$Bin -join ', '
                    Write-Host "  $($C.Action)$Bin$($C.Reset)  [$Aliases]"
                }
            }
        }
        Write-Host ""
    }
    'switches' {
        $All = Get-AllToolkits
        Write-Host ""
        Write-Host "===== SWITCHES =====" -ForegroundColor Cyan
        foreach ($Tk in $All) {
            $M = $Tk.Manifest
            if ($M.switches) {
                Write-Host ""
                Write-Host "$($C.Host)[$($Tk.Name)]$($C.Reset)" -ForegroundColor Magenta
                foreach ($Cat in $M.switches.PSObject.Properties.Name) {
                    Write-Host "  $($C.Param)${Cat}:$($C.Reset)  $($M.switches.$Cat -join ', ')"
                }
            }
        }
        Write-Host ""
    }
    'parameters' {
        if (-not $SubTopic) {
            Write-Host "$($C.Warn)[ERROR] Usage: help-index parameters <action>$($C.Reset)"
            return
        }
        $All = Get-AllToolkits
        $Found = $false
        foreach ($Tk in $All) {
            $M = $Tk.Manifest
            # Use dot notation via variable for PSCustomObject property access
            $ParamObj = $M.parameters.$SubTopic
            if ($M.parameters -and $ParamObj) {
                $Found = $true
                Write-Host ""
                Write-Host "$($C.Host)[$($Tk.Name)]$($C.Reset) $($C.Action)$SubTopic$($C.Reset) parameters:" -ForegroundColor Magenta
                foreach ($Param in $ParamObj.PSObject.Properties.Name) {
                    $Aliases = $ParamObj.$Param -join ', '
                    Write-Host "  $($C.Param)$Param$($C.Reset)  [$Aliases]"
                }
            }
        }
        if (-not $Found) { Write-Host "$($C.Warn)No parameters found for '$SubTopic'$($C.Reset)" }
        Write-Host ""
    }
    'chains' {
        Write-Host ""
        Write-Host "===== CHAIN SYSTEM =====" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Syntax:" -ForegroundColor Yellow
        Write-Host "  <profile> chain list                    - List all chains"
        Write-Host "  <profile> chain new <name> <step>; <step>  - Create chain"
        Write-Host "  <profile> chain run <name> [-Force] [-DryRun] - Run chain"
        Write-Host ""
        Write-Host "Step syntax:" -ForegroundColor Yellow
        Write-Host "  <action> [args...]                    - Local (current toolkit) action"
        Write-Host "  <Toolkit>::<action> [args...]         - Cross-toolkit action"
        Write-Host ""
        Write-Host "Examples:" -ForegroundColor Yellow
        Write-Host "  ani chain new deploy NetToolkit::wol ; SharedToolkit::toast 'Wake sent' ; SSHToolkit::play video.mp4"
        Write-Host "  ani chain run deploy -Force"
        Write-Host "  ani dispatch NetToolkit wol"
        Write-Host ""
    }
    'aliases' {
        Write-Host ""
        Write-Host "===== ALIAS SYSTEM =====" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "User-defined aliases (SharedToolkit/Aliases/*.json):" -ForegroundColor Yellow
        Write-Host "  <profile> alias list                   - List all aliases"
        Write-Host "  <profile> alias set <name> <cmd...>    - Create alias"
        Write-Host "  <profile> alias del <name>             - Delete alias"
        Write-Host ""
        Write-Host "Cross-toolkit dispatch:" -ForegroundColor Yellow
        Write-Host "  <profile> dispatch <Toolkit> <action> [args...]"
        Write-Host "  Examples: ani dispatch NetToolkit wol"
        Write-Host "            ani dispatch SharedToolkit toast 'Hello'"
        Write-Host ""
        Write-Host "Chaining syntax uses :: separator:" -ForegroundColor Yellow
        Write-Host "  NetToolkit::wol"
        Write-Host "  SharedToolkit::toast"
        Write-Host "  SSHToolkit::play"
        Write-Host ""
    }
    'profiles' {
        Write-Host ""
        Write-Host "===== PROFILE MANAGEMENT =====" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "SSHToolkit:  newtarget -Name <name> -IP <ip> -User <user> -Key <path>"
        Write-Host "CloudToolkit: newcloud -Name <name> -Provider <aws|azure|gcp> -Region <region> -Profile <cli-profile>"
        Write-Host "DockerToolkit: newdocker -Name <name> -Host <host> -Context <context>"
        Write-Host ""
        Write-Host "Common:" -ForegroundColor Yellow
        Write-Host "  <profile> config view"
        Write-Host "  <profile> config set <key> <value>"
        Write-Host "  profiles list|show|create|delete|export|import"
        Write-Host ""
    }
    'dispatch' {
        Write-Host ""
        Write-Host "===== CROSS-TOOLKIT DISPATCH =====" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Any profile can invoke actions from any loaded toolkit:" -ForegroundColor Yellow
        Write-Host "  <profile> dispatch <ToolkitName> <Action> [args...]"
        Write-Host ""
        Write-Host "Available toolkits (when loaded):" -ForegroundColor Yellow
        $All = Get-AllToolkits
        foreach ($Tk in $All) { Write-Host "  $($Tk.Name)" }
        Write-Host ""
        Write-Host "This enables composition without chaining:" -ForegroundColor Yellow
        Write-Host "  ani dispatch NetToolkit portscan 10.0.0.5"
        Write-Host "  ani dispatch CloudToolkit instances"
        Write-Host "  ani dispatch DockerToolkit ps"
        Write-Host ""
    }
    'visual' {
        Write-Host ""
        Write-Host "===== VISUAL/INTERACTIVE METHODS (Canonical Patterns) =====" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "SESSION 0 ISOLATION BYPASS (Windows 10/11):" -ForegroundColor Yellow
        Write-Host "  1. File MUST be in C:\Users\Public\ (accessible by ALL users)"
        Write-Host "  2. Detect logged-in user: (Get-CimInstance Win32_ComputerSystem).UserName"
        Write-Host "  3. Use ScheduledTask with -LogonType Interactive"
        Write-Host "  4. ALWAYS clean up: Unregister-ScheduledTask -Confirm:`$false"
        Write-Host ""
        Write-Host "FORCE-PLAY VIDEO (play.ps1):" -ForegroundColor Yellow
        Write-Host "  ani play C:\Users\Public\video.mp4 [wmplayer|edge] [-fs]"
        Write-Host "  wmplayer: native path, use backticks: \"\`$VideoPath\`\" /fullscreen"
        Write-Host "  edge: requires file:/// URL with forward slashes"
        Write-Host ""
        Write-Host "YES/NO POPUP WITH RESPONSE (popup.ps1):" -ForegroundColor Yellow
        Write-Host "  ani popup 'Question?' 'Title' [timeout] [yes-action] [no-action]"
        Write-Host "  Returns: Yes (6), No (7), Timeout"
        Write-Host "  Follow-up actions execute automatically based on response"
        Write-Host ""
        Write-Host "LAN MESSAGES (msg.ps1):" -ForegroundColor Yellow
        Write-Host "  ani msg [auto|msg|wscript|toast|wts] 'message'"
        Write-Host "  auto = WScript Popup via ScheduledTask (most reliable)"
        Write-Host "  msg = native msg.exe (local only, remote needs AllowRemoteRPC=1)"
        Write-Host "  wts = WTSSendMessage API (targets Session 1 directly)"
        Write-Host ""
    }
    'troubleshooting' {
        Write-Host ""
        Write-Host "===== TROUBLESHOOTING =====" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Video plays audio but no video:" -ForegroundColor Yellow
        Write-Host "  → Use wmplayer.exe not explorer.exe"
        Write-Host "  → Ensure file in C:\Users\Public\ (not admin profile)"
        Write-Host "  → Use backticks for quotes: \"\`$VideoPath\`\""
        Write-Host ""
        Write-Host "msg /server:IP fails on Windows 11:" -ForegroundColor Yellow
        Write-Host "  → Set HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\AllowRemoteRPC = 1"
        Write-Host "  → Or use 'auto' method (WScript Popup via ScheduledTask)"
        Write-Host ""
        Write-Host "SCP first attempt 'access denied':" -ForegroundColor Yellow
        Write-Host "  → Normal for Windows OpenSSH, retry once"
        Write-Host ""
        Write-Host "Chain not found:" -ForegroundColor Yellow
        Write-Host "  → Check SharedToolkit/Chains and SSHToolkit/Chains folders"
        Write-Host ""
        Write-Host "Profile alias not working:" -ForegroundColor Yellow
        Write-Host "  → Re-import module: Import-Module SSHToolkit -Force"
        Write-Host "  → Check Profiles/*.json exists"
        Write-Host ""
    }
    default {
        Write-Host "$($C.Warn)[ERROR] Unknown topic: $Topic$($C.Reset)"
        Write-Host "Run 'help-index' for topic list"
    }
}