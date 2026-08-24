
$global:SharedToolkitPath = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent

foreach ($Folder in @("Actions", "Listeners", "Aliases", "Chains")) {
    $FullPath = "$global:SharedToolkitPath\$Folder"
    if (-not (Test-Path $FullPath)) { New-Item -ItemType Directory -Path $FullPath -Force | Out-Null }
}

$ESC = [char]27

# Built-in color themes. The active one is mirrored into $global:ToolColors and can be switched at runtime.
$global:ToolThemes = [PSCustomObject]@{
    default = [PSCustomObject]@{
        Host="$ESC[38;5;208m"; Action="$ESC[38;5;81m"; List="$ESC[38;5;119m"; Sys="$ESC[38;5;141m"
        Param="$ESC[38;5;221m"; Str="$ESC[38;5;210m"; File="$ESC[38;5;45m"; Warn="$ESC[38;5;196m"
        Ok="$ESC[38;5;120m"; Info="$ESC[38;5;39m"; Crit="$ESC[38;5;197m"; Reset="$ESC[0m"
    }
    light = [PSCustomObject]@{
        Host="$ESC[38;5;202m"; Action="$ESC[38;5;25m"; List="$ESC[38;5;28m"; Sys="$ESC[38;5;93m"
        Param="$ESC[38;5;130m"; Str="$ESC[38;5;232m"; File="$ESC[38;5;31m"; Warn="$ESC[38;5;160m"
        Ok="$ESC[38;5;22m"; Info="$ESC[38;5;27m"; Crit="$ESC[38;5;124m"; Reset="$ESC[0m"
    }
    mono = [PSCustomObject]@{
        Host="$ESC[1;37m"; Action="$ESC[1;36m"; List="$ESC[1;32m"; Sys="$ESC[1;35m"
        Param="$ESC[1;33m"; Str="$ESC[0;37m"; File="$ESC[1;34m"; Warn="$ESC[1;31m"
        Ok="$ESC[1;32m"; Info="$ESC[1;36m"; Crit="$ESC[1;31m"; Reset="$ESC[0m"
    }
}

$global:ToolColors = $global:ToolThemes.default

function Get-ToolkitColors {
    <#
    .SYNOPSIS
        Returns the active color theme object for consistent output coloring.
    .DESCRIPTION
        Returns $global:ToolColors if set, otherwise an empty PSCustomObject.
        Use this instead of the repeated pattern: $C = if ($global:ToolColors) { $global:ToolColors } else { [PSCustomObject]@{} }
    #>
    return $global:ToolColors ?? [PSCustomObject]@{}
}

# In-memory event ring buffer (bounded) + persistent log path.
$global:ToolEvents = [System.Collections.Generic.List[PSCustomObject]]::new()
$global:ToolEventsMax = 200
$global:ToolEventLog = "$env:USERPROFILE\Documents\SSHToolkit_Events.log"

# Module unload cleanup
function On-ModuleUnload {
    # Flush any pending events to log
    try {
        if ($global:ToolEvents -and $global:ToolEvents.Count -gt 0) {
            $global:ToolEvents | ForEach-Object {
                $Line = "[$($_.Time)] [EVENT] [$($_.Context)] $($_.Name)$(if ($_.Data) { ' : ' + $_.Data })"
                $Line | Out-File $global:ToolEventLog -Append -ErrorAction SilentlyContinue
            }
        }
    } catch {}
    # Clear global state
    $global:ToolEvents.Clear()
    $global:ToolContext = $null
}

# Register cleanup on shell exit
$null = Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action { On-ModuleUnload } -SupportEvent

# Module-level safety net: any unhandled terminating error is recorded as an event.
trap {
    try { Write-ToolkitError -Message "Unhandled exception: $_" -Severity Critical } catch {}
    continue
}

function Get-ToolStatus {
    param($Config = $null)
    $Cpu = [math]::Round((Get-CimInstance Win32_Processor | Measure-Object -Property LoadPercentage -Average).Average, 0)
    $Os = Get-CimInstance Win32_OperatingSystem
    $Cs = Get-CimInstance Win32_ComputerSystem
    $RamFree = [math]::Round($Os.FreePhysicalMemory / 1MB, 1)
    $RamTotal = [math]::Round($Cs.TotalPhysicalMemory / 1GB, 1)
    $Online = if ($Config) { Test-Connection -ComputerName $Config.IP -Count 1 -Quiet } else { $null }
    [PSCustomObject]@{
        Clock    = Get-Date -Format "HH:mm:ss"
        CPU      = $Cpu
        RAMFree  = $RamFree
        RAMTotal = $RamTotal
        Context  = if ($Config) { "$($Config.User)@$($Config.IP)" } else { "local" }
        Online   = $Online
        LastEvent = if ($global:ToolEvents.Count) { $global:ToolEvents[-1].Name } else { $null }
    }
}

function Write-ToolkitEvent {
    param([string]$Name, $Data = $null, $Config = $null)
    $Ev = [PSCustomObject]@{
        Time    = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Name    = $Name
        Context = if ($Config) { $Config.IP } else { "LocalSystem" }
        Data    = $Data
    }
    $global:ToolEvents.Add($Ev)
    if ($global:ToolEvents.Count -gt $global:ToolEventsMax) { $global:ToolEvents.RemoveAt(0) }
    $Line = "[$($Ev.Time)] [EVENT] [$($Ev.Context)] $($Ev.Name)$(if ($Ev.Data) { ' : ' + $Ev.Data })"
    try { $Line | Out-File $global:ToolEventLog -Append } catch {}
    $Ev
}

function Get-ActionArguments {
    <#
    .SYNOPSIS
        Parses action arguments into positional args and named switches.
    .DESCRIPTION
        Standardizes argument parsing across all actions. Returns a hashtable with:
        - ArgsOnly: array of positional arguments (excluding known switches)
        - Switches: hashtable of detected switches (Force, DryRun, ConfirmAnswer, Format, Help)
        - Format: detected output format (json, csv, raw, table)
    .PARAMETER Arguments
        The arguments array passed to the action.
    #>
    [CmdletBinding()]
    param([array]$Arguments)

    $KnownSwitches = @("-Force", "-f", "-DryRun", "-ConfirmAnswer", "-json", "-csv", "-raw", "-table", "-h", "-?", "--help")
    $ArgsOnly = @($Arguments | Where-Object { $_ -notin $KnownSwitches })
    $Switches = @{}

    $Switches.Force = $Arguments -contains '-Force' -or $Arguments -contains '-f'
    $Switches.DryRun = $Arguments -contains '-DryRun'
    $Switches.ConfirmAnswer = $Arguments -contains '-ConfirmAnswer'
    $Switches.Help = $Arguments -contains '-h' -or $Arguments -contains '-?' -or $Arguments -contains '--help'

    if ($Arguments -contains '-json') { $Switches.Format = 'json' }
    elseif ($Arguments -contains '-csv') { $Switches.Format = 'csv' }
    elseif ($Arguments -contains '-raw') { $Switches.Format = 'raw' }
    elseif ($Arguments -contains '-table') { $Switches.Format = 'table' }
    else { $Switches.Format = 'table' }

    return @{
        ArgsOnly = $ArgsOnly
        Switches = $Switches
        Format = $Switches.Format
    }
}

function Write-ToolkitError {
    param([string]$Message, [string]$Severity = "Error", $Config = $null)
    $C = $global:ToolColors
    $Ctx = if ($Config) { $Config.IP } else { "LocalSystem" }
    Write-Host "$($C.Warn)[$Severity]$($C.Reset) $Message" -ForegroundColor Red
    $LogLine = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$Ctx] [ERROR] $Message"
    try { $LogLine | Out-File $global:ToolEventLog -Append } catch {}
    Write-ToolkitEvent -Name "Error" -Data "$Severity : $Message" -Config $Config
    try { & "$global:SharedToolkitPath\Actions\toast.ps1" -Config $Config -Arguments @("Error", $Message) } catch {}
}

function Read-ToolkitPrompt {
    [CmdletBinding()]
    param(
        [string]$Message = "Choose an action",
        [string]$Title = "SSHToolkit",
        [string[]]$Buttons = @("OK"),
        [string]$Default = "",
        [string]$Answer = $null,
        [switch]$Gui,
        [int]$TimeoutSeconds = 30
    )
    $C = $global:ToolColors

    if ($null -ne $Answer -and $Answer -ne "") {
        Write-Host "$($C.Info)[PROMPT]$($C.Reset) $Title : $Message → (injected) $Answer" -ForegroundColor DarkGray
        return $Answer
    }

    if ($env:TOOLKIT_PROMPT_DEFAULT) {
        Write-Host "$($C.Info)[PROMPT]$($C.Reset) $Title : $Message → (env) $env:TOOLKIT_PROMPT_DEFAULT" -ForegroundColor DarkGray
        return $env:TOOLKIT_PROMPT_DEFAULT
    }

    $UseGui = $Gui -and [Environment]::UserInteractive
    if ($UseGui) {
        try {
            $ws = New-Object -ComObject WScript.Shell -ErrorAction Stop
            [int]$ButtonType = switch ($Buttons.Count) { 1 { 0 } 2 { 4 } 3 { 3 } default { 0 } }
            $Label = $Buttons -join " / "
            $Result = $ws.Popup($Message, $TimeoutSeconds, "$Title ($Label)", $ButtonType + 32)
            if ($Result -ne -1) {
                $Choice = switch ($Result) {
                    1 { $Buttons[0] }
                    6 { $Buttons[0] }
                    7 { if ($Buttons[1]) { $Buttons[1] } else { $Buttons[0] } }
                    2 { "Cancel" }
                    3 { "Abort" }
                    4 { "Retry" }
                    5 { "Ignore" }
                    default { if ($Default) { $Default } else { $Buttons[0] } }
                }
                Write-Host "$($C.Info)[PROMPT]$($C.Reset) $Title : $Message → $Choice" -ForegroundColor Cyan
                return $Choice
            }
        } catch {
            Write-Host "$($C.Warn)[PROMPT]$($C.Reset) GUI unavailable, using console" -ForegroundColor Yellow
        }
    }

    Write-Host ""
    Write-Host "$($C.Sys)═══ $Title ═══$($C.Reset)" -ForegroundColor Yellow
    Write-Host "$($C.Str)$Message$($C.Reset)"
    for ($i = 0; $i -lt $Buttons.Count; $i++) {
        Write-Host "  $($C.Param)[$i]$($C.Reset) $($Buttons[$i])"
    }
    if ($Default) { Write-Host "$($C.Info)Default (Enter): $Default$($C.Reset)" -ForegroundColor Gray }
    try {
        $Sel = Read-Host "Choose (0-$($Buttons.Count - 1))"
    } catch {
        if ($Default) { return $Default } else { return $Buttons[0] }
    }
    if ($Sel -eq "" -and $Default) { return $Default }
    $Idx = 0
    if ([int]::TryParse($Sel, [ref]$Idx) -and $Idx -ge 0 -and $Idx -lt $Buttons.Count) { return $Buttons[$Idx] }
    if ($Default) { return $Default } else { return $Buttons[0] }
}

function Confirm-ToolkitAction {
    [CmdletBinding()]
    param(
        [string]$Problem = "",
        [string]$WillDo = "",
        [string]$Target = "",
        [string]$Consequence = "",
        [switch]$Dangerous,
        [string]$Answer = $null
    )
    $C = $global:ToolColors
    $Header = if ($Dangerous) { "DANGEROUS ACTION — CONFIRM" } else { "CONFIRM ACTION" }
    Write-Host ""
    Write-Host "$($C.Warn)═══ $Header ═══$($C.Reset)" -ForegroundColor Red
    if ($Problem) {
        Write-Host "$($C.Sys)WHAT'S WRONG:$($C.Reset)"
        Write-Host "  $($C.Str)$Problem$($C.Reset)"
    }
    if ($WillDo) {
        Write-Host "$($C.Sys)WILL DO:$($C.Reset)"
        foreach ($Line in ($WillDo -split "`n")) {
            Write-Host "  $($C.Action)$Line$($C.Reset)"
        }
    }
    if ($Target) {
        Write-Host "$($C.Sys)TARGET:$($C.Reset) $($C.Host)$Target$($C.Reset)"
    }
    if ($Consequence) {
        Write-Host "$($C.Warn)NOTE:$($C.Reset) $($C.Str)$Consequence$($C.Reset)"
    }
    Write-Host ""

    if ($null -eq $Answer -or $Answer -eq "") { $Answer = $env:TOOLKIT_CONFIRM_DEFAULT }

    $Choice = Read-ToolkitPrompt -Message "Proceed?" -Title $Header -Buttons @("Yes", "No") -Default "No" -Answer $Answer
    $Ok = ($Choice -eq "Yes")
    if ($Ok) {
        Write-Host "$($C.Ok)Confirmed.$($C.Reset)" -ForegroundColor Green
    } else {
        Write-Host "$($C.Warn)Cancelled by user.$($C.Reset)" -ForegroundColor Yellow
    }
    [void](Write-ToolkitEvent -Name "Confirm" -Data "problem=$Problem choice=$Choice" -Config $null)
    return $Ok
}

function Request-ToolkitConfirmation {
    [CmdletBinding()]
    param(
        [string]$Verb = "execute command",
        [string]$Command = "",
        $Config = $null,
        [array]$Arguments = @(),
        [switch]$Dangerous
    )
    if ($Arguments -contains "-Force" -or $Arguments -contains "-f") { return $true }
    $Target = if ($Config) { "$($Config.User)@$($Config.IP)" } else { "local" }
    $WillDo = if ($Command.Trim()) { "$Verb`n  > $Command" } else { $Verb }
    Confirm-ToolkitAction -Problem "About to '$Verb' on $Target" -WillDo $WillDo -Target $Target -Dangerous:$Dangerous -Answer $env:TOOLKIT_CONFIRM_DEFAULT
}

function Format-ChainPreview {
    param([string]$ChainFile)
    if (-not (Test-Path $ChainFile)) { return "  (chain file not found: $ChainFile)" }
    try {
        $Chain = Get-Content $ChainFile | ConvertFrom-Json
    } catch {
        return "  (failed to parse chain: $_)"
    }
    $Lines = [System.Collections.ArrayList]::new()
    if ($Chain.Description) { [void]$Lines.Add("  $($Chain.Description)") }
    $Idx = 0
    foreach ($Step in $Chain.Steps) {
        $Idx++
        $ArgsStr = if ($Step.Args) { ($Step.Args | ForEach-Object { "'$_'" }) -join " " } else { "" }
        $Prefix = if ($Step.Toolkit) { "$($Step.Toolkit)::" } else { "" }
        $Label = switch ($Step.Action) {
            { $_ -in @("run", "service", "process", "shutdown", "push", "pull") } { "⚠ $Prefix$_" }
            { $_ -in @("lock", "snap", "msg", "wol") } { "⚠ $Prefix$_" }
            default { "$Prefix$_" }
        }
        [void]$Lines.Add("  ${Idx}. $Label $ArgsStr")
    }
    $Lines -join "`n"
}

function Send-ToolkitNotification {
    param([string]$Title = "SSHToolkit", [string]$Message = "", [string]$Severity = "Info", $Config = $null, [string]$Source = "", [hashtable]$Actions = $null)
    $C = $global:ToolColors
    $Sev = $Severity.ToLower()
    $Ctx = if ($Config) { "$($Config.User)@$($Config.IP)" } else { "local" }
    $Stamp = Get-Date -Format "HH:mm:ss"

    $FullMessage = "[$Stamp] $Message`nTarget: $Ctx$(if ($Source) { "  Source: $Source" })"

    try { & "$global:SharedToolkitPath\Actions\toast.ps1" -Config $Config -Arguments @("$Severity : $Title", $FullMessage) } catch {}
    if ($Sev -in @("error", "critical", "warn")) { try { [Console]::Beep(440, 300) } catch {} }
    if ($Sev -eq "critical") { try { & "$global:SharedToolkitPath\Actions\speak.ps1" -Arguments @($Message) } catch {} }

    if ($Sev -eq "interactive" -and $Actions -and $Actions.Count) {
        $Buttons = @($Actions.Keys)
        $ChainMap = ($Actions.GetEnumerator() | ForEach-Object { "$($_.Key):$($_.Value)" }) -join ";"
        $Choice = Read-ToolkitPrompt -Message $Message -Title $Title -Buttons $Buttons -Default $Buttons[0] -Answer $env:TOOLKIT_PROMPT_DEFAULT
        if ($Actions[$Choice]) {
            try { Invoke-UniversalToolkitRouter -Action "chain" -ForwardedArgs @("run", $Actions[$Choice]) } catch {
                Write-ToolkitError -Message "Interactive chain '$($Actions[$Choice])' failed: $_" -Severity Error -Config $Config
            }
        }
    }

    Write-Host "$($C.Info)[NOTIFY]$($C.Reset) ($Severity) $Title : $Message" -ForegroundColor Cyan
    Write-ToolkitEvent -Name "Notify" -Data "$Severity : $Title - $Message" -Config $Config
}

function Get-ToolkitHelp {
    param([string]$Caller, [string]$TargetTopic, [string]$ChildModulePath)
    $C = $global:ToolColors
    Write-Host ""
    Write-Host "===== Orchestration Platform : Global Shared Framework Engine Help =====" -ForegroundColor Cyan
    Write-Host "Active Context Target: $($C.Host)$Caller$($C.Reset)"
    if ($TargetTopic -eq 'config') {
        Write-Host ""
        Write-Host "[System Configuration Parameters Help]" -ForegroundColor Magenta
        Write-Host "Syntax: $Caller config view"
        Write-Host "Syntax: $Caller config set [IP/User/Key] [value]"
        Write-Host "Keys: IP (e.g. 10.0.0.125), User (e.g. sshadmin), Key (e.g. C:\Users\Rober\.ssh\id_lan)"
    }
    elseif ($TargetTopic -and $TargetTopic -like "find *") {
        $Term = $TargetTopic.Substring(5).Trim()
        $Hits = [System.Collections.ArrayList]::new()
        foreach ($Dir in @("$ChildModulePath\Actions", "$global:SharedToolkitPath\Actions", "$ChildModulePath\Listeners", "$global:SharedToolkitPath\Listeners")) {
            if (Test-Path $Dir) {
                Get-ChildItem "$Dir\*.ps1" | ForEach-Object {
                    $Lines = Get-Content $_.FullName -Head 2
                    $Desc = ($Lines | Where-Object { $_ -match '#\s*Description:\s*(.*)' } | ForEach-Object { $Matches[1].Trim() })
                    if ($_.BaseName -like "*$Term*" -or ($Desc -and $Desc -like "*$Term*")) {
                        [void]$Hits.Add([PSCustomObject]@{Name = $_.BaseName; Type = $(if ($Dir -match 'Listeners') { 'Listener' } else { 'Action' }); Desc = $Desc })
                    }
                }
            }
        }
        if ($Hits.Count) {
            Write-Host ""
            Write-Host "[Search results for '$Term']" -ForegroundColor Yellow
            foreach ($H in $Hits) { Write-Host "  $Caller $($C.Action)$($H.Name)$($C.Reset) ($($H.Type)) - $($H.Desc)" }
        } else { Write-Host "[No matches for '$Term']" -ForegroundColor Red }
    }
    elseif ($TargetTopic -and $TargetTopic -ne 'help') {
        $FileFound = $null
        foreach ($Dir in @("$ChildModulePath\Actions", "$global:SharedToolkitPath\Actions", "$ChildModulePath\Listeners", "$global:SharedToolkitPath\Listeners")) {
            if (Test-Path "$Dir\$TargetTopic.ps1") { $FileFound = "$Dir\$TargetTopic.ps1" ; break }
        }
        if ($FileFound) {
            $Lines = Get-Content $FileFound -Head 12
            $Type = ($Lines | Where-Object { $_ -match '#\s*Type:\s*(\w+)' } | ForEach-Object { $Matches[1] })
            $Desc = ($Lines | Where-Object { $_ -match '#\s*Description:\s*(.*)' } | ForEach-Object { $Matches[1].Trim() })
            if (-not $Type) { $Type = "Action" }
            Write-Host ""
            Write-Host "[Plugin Help]: $($C.Action)$TargetTopic$($C.Reset)"
            Write-Host "Type: " -NoNewline
            if ($Type -eq 'Listener') { Write-Host "$($C.List)$Type$($C.Reset)" } else { Write-Host "$($C.Action)$Type$($C.Reset)" }
            if ($Desc) { Write-Host "Description: $Desc" }
            Write-Host "Syntax: $Caller $($C.Action)$TargetTopic$($C.Reset) $($C.Str)[arguments]$($C.Reset)"
        } else {
            Write-Host "[ERROR] No component or action matching '$TargetTopic' was found." -ForegroundColor Red
        }
    }
    else {
        Write-Host ""
        Write-Host "Core Built-In Actions:" -ForegroundColor Yellow
        Write-Host "  $Caller online  - ICMP connection check to profile IP."
        Write-Host "  $Caller ssh     - Passwordless administrative SSH terminal."
        Write-Host "  $Caller config view - Show profile parameters."
        Write-Host "  $Caller config set [key] [value] - Change profile parameters."
        Write-Host "  $Caller help find <term> - Search actions/listeners by name or description."
        $ChildActions  = Get-ChildItem "$ChildModulePath\Actions\*.ps1" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty BaseName
        $SharedActions = Get-ChildItem "$global:SharedToolkitPath\Actions\*.ps1" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty BaseName
        if ($ChildActions -or $SharedActions) {
            Write-Host ""
            Write-Host "Action Plugins:" -ForegroundColor Yellow
            foreach ($A in $ChildActions)  { Write-Host "  $Caller $($C.Action)$A$($C.Reset) (SSH-specific)" }
            foreach ($A in $SharedActions) { Write-Host "  $Caller $($C.Action)$A$($C.Reset) (Shared)" }
        }
        $ChildList  = Get-ChildItem "$ChildModulePath\Listeners\*.ps1" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty BaseName
        $SharedList = Get-ChildItem "$global:SharedToolkitPath\Listeners\*.ps1" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty BaseName
        if ($ChildList -or $SharedList) {
            Write-Host ""
            Write-Host "Listeners:" -ForegroundColor Yellow
            foreach ($L in $ChildList)  { Write-Host "  $Caller $($C.List)$L$($C.Reset) (SSH-specific)" }
            foreach ($L in $SharedList) { Write-Host "  $Caller $($C.List)$L$($C.Reset) (Shared)" }
        }
    }
    Write-Host ""
}

function Use-SharedAsset {
    [CmdletBinding()]
    param([string]$Type, [string]$AssetName, $Config, $ForwardedArgs)
    $TargetScript = "$global:SharedToolkitPath\$Type\$AssetName.ps1"
    if (Test-Path $TargetScript) {
        & $TargetScript -Config $Config -Arguments $ForwardedArgs
        return $true
    }
    return $false
}

$global:ToolCommandLog = "$env:USERPROFILE\Documents\SSHToolkit_CommandHistory.log"

function Write-ToolCommand {
    param([string]$ContextName, [string]$Action, [array]$Arguments = @(), [string]$Status = "run")
    $Stamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $ArgsStr = $Arguments -join " "
    $Line = "[$Stamp] [$ContextName] [$Status] $Action $ArgsStr"
    try { $Line | Out-File $global:ToolCommandLog -Append } catch {}
}

function Invoke-CrossToolkitAction {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$Toolkit,
        [Parameter(Mandatory=$true)][string]$Action,
        [array]$Arguments = @(),
        $Config = $null
    )
    $ModulesPath = "$env:USERPROFILE\Documents\PowerShell\Modules"
    $ToolkitFolder = "$ModulesPath\$Toolkit"
    $RouterFile = "$ToolkitFolder\$Toolkit.psm1"
    if (-not (Test-Path $RouterFile)) { Write-Host "No module named '$Toolkit' at $RouterFile" -ForegroundColor Red ; return $false }
    $ActionFile = "$ToolkitFolder\Actions\$Action.ps1"
    if (-not (Test-Path $ActionFile)) { Write-Host "Toolkit '$Toolkit' has no action '$Action'" -ForegroundColor Red ; return $false }
    if (-not (Get-Command $Toolkit -ErrorAction SilentlyContinue)) {
        . $RouterFile
    }
    & $ActionFile -Config $Config -Arguments $Arguments
    $true
}

function Initialize-ToolkitCompletion {
    <#
    .SYNOPSIS
        Registers tab completion for all installed toolkit aliases.
    .DESCRIPTION
        Call this function in your PowerShell profile AFTER importing the toolkit modules
        to enable tab completion for all toolkit commands. This avoids module-load recursion
        issues that occur when completers are registered during module import.
    .EXAMPLE
        Import-Module SSHToolkit
        Import-Module NetToolkit
        Initialize-ToolkitCompletion
    #>
    $ModulesPath = "$env:USERPROFILE\Documents\PowerShell\Modules"
    $Toolkits = @("SSHToolkit", "NetToolkit", "MediaToolkit", "SecToolkit", "FileToolkit")
    foreach ($Toolkit in $Toolkits) {
        $ProfilePath = "$env:USERPROFILE\Documents\PowerShell\Modules\$Toolkit\Profiles"
        if (Test-Path $ProfilePath) {
            Get-ChildItem "$ProfilePath\*.json" -ErrorAction SilentlyContinue | ForEach-Object {
                $Alias = $_.BaseName
                Register-ToolkitArgumentCompleter -AliasName $Alias -ToolkitName $Toolkit
            }
        }
    }
    # Also register for SharedToolkit local actions
    $SharedActions = @("beep", "toast", "log", "speak", "clip", "open", "now", "sys", "hash", "net", "shot", "timer", "battery", "procs", "svc", "theme", "alias", "events", "notify", "ask", "alert", "dashboard", "timer", "battery", "procs", "svc", "registry", "dispatch", "backup", "restore", "schedule", "history", "search", "logs", "health", "profiles", "shell", "dispatch", "alert", "ask")
    $SharedActions | Select-Object -Unique | ForEach-Object {
        Register-ArgumentCompleter -CommandName "ani" -ParameterName Action -ScriptBlock {
            param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameter)
            # This is a fallback - real completion comes from toolkit-specific completers
        } | Out-Null
    }
}

function Format-ToolOutput {
    <#
    .SYNOPSIS
        Formats output in JSON, CSV, or raw text format.
    .DESCRIPTION
        Standardized output formatting helper for all toolkit actions.
    .PARAMETER InputObject
        The object(s) to format.
    .PARAMETER Format
        Output format: json, csv, table, raw (default: table)
    .PARAMETER Properties
        Specific properties to include (for table/csv).
    .EXAMPLE
        Get-Process | Format-ToolOutput -Format json
        Get-Service | Format-ToolOutput -Format csv -Properties Name,Status
    #>
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline=$true, Mandatory=$true)]
        $InputObject,
        [ValidateSet('json', 'csv', 'table', 'raw')]
        [string]$Format = 'table',
        [string[]]$Properties = @()
    )

    begin {
        $Data = @()
    }
    process {
        $Data += $InputObject
    }
    end {
        if (-not $Data) { return }
        switch ($Format) {
            'json' {
                $Data | ConvertTo-Json -Depth 4 -Compress
            }
'csv' {
                if ($Properties) {
                    $Data | Select-Object -Property $Properties | ConvertTo-Csv -NoTypeInformation | Out-String
                } else {
                    $Data | ConvertTo-Csv -NoTypeInformation | Out-String
                }
            }
            'raw' {
                if ($Properties) {
                    $Data | ForEach-Object {
                        $Props = @()
                        foreach ($Prop in $Properties) {
                            $Props += "$($_.$Prop)"
                        }
                        $Props -join ' | '
                    }
                } else {
                    $Data | ForEach-Object { $_ -join ' | ' }
                }
            }
            default {
                if ($Properties) {
                    $Data | Format-Table -AutoSize -Property $Properties | Out-String
                } else {
                    $Data | Format-Table -AutoSize | Out-String
                }
            }
        }
    }
}

function Register-ToolkitArgumentCompleter {
    param([string]$AliasName, [string]$ToolkitName)
    $ActionNames = @(Get-ChildItem "$global:SharedToolkitPath\..\$ToolkitName\Actions\*.ps1" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty BaseName)
    $SubNames = @("config", "help", "online", "ssh", "chain", "history", "registry", "dispatch", "backup", "restore", "schedule", "theme", "alias", "events", "notify", "ask", "alert", "dashboard", "timer", "battery", "sys", "procs", "svc", "net", "hash", "find", "grep", "log", "beep", "toast", "speak", "open", "now", "clip", "shot")
    $AllActions = @($ActionNames + $SubNames) | Select-Object -Unique | Sort-Object
    Register-ArgumentCompleter -CommandName $AliasName -ParameterName Action -ScriptBlock {
        param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameter)
        $AllActions | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object { [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_) }
    } | Out-Null
}

Export-ModuleMember -function Use-SharedAsset, Get-ToolkitHelp, Write-ToolkitEvent, Write-ToolkitError, Send-ToolkitNotification, Read-ToolkitPrompt, Confirm-ToolkitAction, Request-ToolkitConfirmation, Format-ChainPreview, Get-ToolStatus, Invoke-CrossToolkitAction, Get-ToolkitRouter, Write-ToolCommand, Register-ToolkitArgumentCompleter, Initialize-ToolkitCompletion, Format-ToolOutput, Get-ToolkitColors, Get-ActionArguments

