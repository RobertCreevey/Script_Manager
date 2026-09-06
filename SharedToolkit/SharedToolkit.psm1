
$global:SharedToolkitPath = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent

foreach ($Folder in @("Actions", "Listeners", "Aliases", "Chains")) {
    $FullPath = "$global:SharedToolkitPath\$Folder"
    if (-not (Test-Path $FullPath)) { New-Item -ItemType Directory -Path $FullPath -Force | Out-Null }
}

$ESC = [char]27

# Built-in color themes. The active one is mirrored into $global:ToolColors and can be switched at runtime.
# Palette convention: Warn = yellow (warnings / advisory notes), Crit = red
# (errors). Action/router error paths print [ERROR] via $C.Crit; notes and
# status lines stay $C.Warn so warnings and errors read as distinct colors.
# (Migrated from $C.Warn -> $C.Crit across all [ERROR] paths.)
$global:ToolThemes = [PSCustomObject]@{
    default = [PSCustomObject]@{
        Host = "$ESC[38;5;208m"; Action = "$ESC[38;5;81m"; List = "$ESC[38;5;119m"; Sys = "$ESC[38;5;141m"
        Param = "$ESC[38;5;221m"; Str = "$ESC[38;5;210m"; File = "$ESC[38;5;45m"; Warn = "$ESC[38;5;226m"
        Ok = "$ESC[38;5;120m"; Info = "$ESC[38;5;39m"; Crit = "$ESC[38;5;197m"; Step = "$ESC[38;5;51m"; Category = "$ESC[38;5;201m"; Muted = "$ESC[38;5;245m"; Reset = "$ESC[0m"
    }
    light   = [PSCustomObject]@{
        Host = "$ESC[38;5;202m"; Action = "$ESC[38;5;25m"; List = "$ESC[38;5;28m"; Sys = "$ESC[38;5;93m"
        Param = "$ESC[38;5;130m"; Str = "$ESC[38;5;232m"; File = "$ESC[38;5;31m"; Warn = "$ESC[38;5;220m"
        Ok = "$ESC[38;5;22m"; Info = "$ESC[38;5;27m"; Crit = "$ESC[38;5;124m"; Step = "$ESC[38;5;45m"; Category = "$ESC[38;5;164m"; Muted = "$ESC[38;5;246m"; Reset = "$ESC[0m"
    }
    mono    = [PSCustomObject]@{
        Host = "$ESC[1;37m"; Action = "$ESC[1;36m"; List = "$ESC[1;32m"; Sys = "$ESC[1;35m"
        Param = "$ESC[1;33m"; Str = "$ESC[0;37m"; File = "$ESC[1;34m"; Warn = "$ESC[33m"
        Ok = "$ESC[1;32m"; Info = "$ESC[1;36m"; Crit = "$ESC[1;31m"; Step = "$ESC[1;36m"; Category = "$ESC[1;35m"; Muted = "$ESC[2m"; Reset = "$ESC[0m"
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
$global:ToolCommandLog = "$env:USERPROFILE\Documents\SSHToolkit_CommandHistory.log"

# Structured logging configuration
$global:ToolLogConfig = @{
    Level          = "Info"      # Debug, Info, Warn, Error, Critical
    JsonFormat     = $false      # Write JSON lines
    RotateSizeMB   = 10          # Rotate at 10MB
    MaxFiles       = 5           # Keep 5 rotated files
    IncludeContext = $true       # Include profile context
}

$global:LogLevels = @{
    Debug    = 0
    Info     = 1
    Warn     = 2
    Error    = 3
    Critical = 4
}

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
    }
    catch {}
    # Clear global state
    $global:ToolEvents.Clear()
    $global:ToolContext = $null
}

# Register cleanup on shell exit
$null = Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action { On-ModuleUnload } -SupportEvent

# Plugin system auto-discovery.
# Loaded at MODULE script scope (foreach statement, NOT a ForEach-Object
# pipeline) so the resulting functions persist in the module and can be
# exported as commands.
$PluginRoot = "$env:USERPROFILE\.toolkit\plugins"
$PluginExportFunctions = @()
if (Test-Path $PluginRoot) {
    $pluginFiles = @(Get-ChildItem "$PluginRoot\*.ps1" -ErrorAction SilentlyContinue)
    foreach ($pf in $pluginFiles) {
        $before = (Get-ChildItem Function:).Name
        try {
            . $pf.FullName
            $after = (Get-ChildItem Function:).Name
            $PluginExportFunctions += ($after | Where-Object { $_ -notin $before })
            # TODO: Route status output through a shared Write-ToolkitStatus helper
            #       (Install/Ok/Warn/Err/Category) so bootstrap/silent contexts can
            #       be controlled in one place instead of ad-hoc Write-Host here.
            if (-not $global:ToolkitSuppressPluginLoad) {
                Write-Host "[Plugin] Loaded: $($pf.BaseName)" -ForegroundColor DarkCyan
            }
        }
        catch {
            Write-Host "[Plugin] Failed to load $($pf.BaseName): $_" -ForegroundColor DarkRed
        }
    }
}

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
        Clock     = Get-Date -Format "HH:mm:ss"
        CPU       = $Cpu
        RAMFree   = $RamFree
        RAMTotal  = $RamTotal
        Context   = if ($Config) { "$($Config.User)@$($Config.IP)" } else { "local" }
        Online    = $Online
        LastEvent = if ($global:ToolEvents.Count) { $global:ToolEvents[-1].Name } else { $null }
    }
}

function Write-ToolkitEvent {
    param([string]$Name, $Data = $null, $Config = $null, [string]$Level = "Info")
    $Ev = [PSCustomObject]@{
        Time    = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Level   = $Level
        Name    = $Name
        Context = if ($Config) { $Config.IP } else { "LocalSystem" }
        Data    = $Data
    }
    $global:ToolEvents.Add($Ev)
    if ($global:ToolEvents.Count -gt $global:ToolEventsMax) { $global:ToolEvents.RemoveAt(0) }
    
    # Write to log file with structured format
    $LogEntry = @{
        timestamp = $Ev.Time
        level     = $Ev.Level
        name      = $Ev.Name
        context   = $Ev.Context
        data      = $Ev.Data
    }
    
    if ($global:ToolLogConfig.JsonFormat) {
        $Line = $LogEntry | ConvertTo-Json -Compress -Depth 3
    }
    else {
        $Line = "[$($Ev.Time)] [$($Ev.Level)] [$($Ev.Context)] $($Ev.Name)$(if ($Ev.Data) { ' : ' + $Ev.Data })"
    }
    
    try { 
        $Line | Out-File $global:ToolEventLog -Append -Encoding utf8 -ErrorAction SilentlyContinue
        
        # Log rotation
        $LogFile = Get-Item $global:ToolEventLog -ErrorAction SilentlyContinue
        if ($LogFile -and $LogFile.Length -gt ($global:ToolLogConfig.RotateSizeMB * 1MB)) {
            Rotate-LogFile
        }
    }
    catch {}
    $Ev
}

# Compatibility shims: router code in SSHToolkit/Cloud/Docker/Git/… invokes these
# legacy entrypoints. They delegate to the canonical SharedToolkit functions
# (Get-ToolkitHelp / Write-ToolkitEvent) so help rendering and event emission
# actually resolve instead of throwing CommandNotFoundException.
function Invoke-ToolEvent {
    [CmdletBinding()]
    param([string]$Name, $Data = $null, $Config = $null)
    Write-ToolkitEvent -Name $Name -Data $Data -Config $Config
}
function Invoke-SharedHelpSystem {
    [CmdletBinding()]
    param([string]$Caller, [string]$TargetTopic, [string]$ChildModulePath)
    Get-ToolkitHelp -Caller $Caller -TargetTopic $TargetTopic -ChildModulePath $ChildModulePath
}
function Invoke-SharedAsset {
    [CmdletBinding()]
    param([string]$Type, [string]$AssetName, $Config, $ForwardedArgs)
    Use-SharedAsset -Type $Type -AssetName $AssetName -Config $Config -ForwardedArgs $ForwardedArgs
}

function Rotate-LogFile {
    $LogPath = $global:ToolEventLog
    $MaxFiles = $global:ToolLogConfig.MaxFiles
    for ($i = $MaxFiles - 1; $i -ge 1; $i--) {
        $Old = "$LogPath.$i"
        $New = "$LogPath.$($i + 1)"
        if (Test-Path $Old) { Move-Item $Old $New -Force }
    }
    if (Test-Path $LogPath) { Move-Item $LogPath "$LogPath.1" -Force }
}

function Write-ToolkitLog {
    <#
    .SYNOPSIS
        Writes a structured log entry with level and optional color.
    .DESCRIPTION
        Writes to console (with color) and log file (structured JSON or text).
    .PARAMETER Level
        Log level: Debug, Info, Warn, Error, Critical
    .PARAMETER Message
        Log message
    .PARAMETER Data
        Optional structured data
    .PARAMETER Config
        Toolkit config for context
    #>
    [CmdletBinding()]
    param(
        [ValidateSet('Debug', 'Info', 'Warn', 'Error', 'Critical')]
        [string]$Level = 'Info',
        [string]$Message,
        $Data = $null,
        $Config = $null
    )
    
    $C = Get-ToolkitColors
    $Ctx = if ($Config) { $Config.IP } else { "LocalSystem" }
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    
    # Console output with colors
    $LevelColor = switch ($Level) {
        'Debug' { $C.Info }
        'Info' { $C.Ok }
        'Warn' { $C.Warn }
        'Error' { $C.Crit }
        'Critical' { $C.Crit }
    }
    
    # Only show if level meets threshold
    $Threshold = $global:ToolLogConfig.Level
    $LevelValue = $global:LogLevels[$Level]
    $ThresholdValue = $global:LogLevels[$Threshold]
    if ($LevelValue -ge $ThresholdValue) {
        $Prefix = "[$Timestamp] [$Level] [$Ctx]"
        Write-Host "$($LevelColor)$Prefix$($C.Reset) $Message"
    }
    
    # Write to event log
    Write-ToolkitEvent -Name "Log" -Data "$Level : $Message" -Config $Config -Level $Level
    
    # Also write to command log if it's an action
    if ($Level -in @('Info', 'Warn', 'Error', 'Critical')) {
        $LogLine = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$Ctx] [$Level] $Message"
        try { $LogLine | Out-File $global:ToolCommandLog -Append -Encoding utf8 } catch {}
    }
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
        Format   = $Switches.Format
    }
}

function Write-ToolkitError {
    param([string]$Message, [string]$Severity = "Error", $Config = $null)
    Write-ToolkitLog -Level "Error" -Message $Message -Config $Config
    try { & "$global:SharedToolkitPath\Actions\toast.ps1" -Config $Config -Arguments @("Error", $Message) } catch {}
}

function Invoke-SSHCommand {
    <#
    .SYNOPSIS
        Executes an SSH command with retry logic and structured error handling.
    .DESCRIPTION
        Executes SSH commands with configurable retry logic, timeout, and structured error objects.
    .PARAMETER Config
        Toolkit config containing IP, User, Key
    .PARAMETER Command
        Command to execute on remote host
    .PARAMETER RetryCount
        Number of retry attempts (default: 2)
    .PARAMETER RetryDelay
        Delay between retries in seconds (default: 2)
    .PARAMETER Timeout
        Command timeout in seconds (default: 30)
    .PARAMETER CaptureOutput
        Whether to capture stdout/stderr (default: $true)
    .RETURNS
        Hashtable with Success, ExitCode, Output, Error, Duration
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $Config,
        [Parameter(Mandatory = $true)]
        [string]$Command,
        [int]$RetryCount = 2,
        [int]$RetryDelay = 2,
        [int]$Timeout = 30,
        [switch]$CaptureOutput = $true
    )
    
    $C = Get-ToolkitColors
    $IP = $Config.IP
    $User = $Config.User
    $Key = $Config.Key
    $StartTime = Get-Date
    
    $SshArgs = @("-i", $Key, "-o", "ConnectTimeout=$Timeout", "-o", "BatchMode=yes", "-o", "StrictHostKeyChecking=no", "${User}@${IP}", $Command)
    
    $Attempt = 0
    $LastError = $null
    
    while ($Attempt -le $RetryCount) {
        $Attempt++
        $AttemptStart = Get-Date
        
        try {
            $Result = @{Success = $false; ExitCode = -1; Output = ""; Error = ""; Duration = 0 }
            
            if ($CaptureOutput) {
                $Process = Start-Process -FilePath "ssh" -ArgumentList $SshArgs -NoNewWindow -Wait -PassThru -RedirectStandardOutput "ssh_out.txt" -RedirectStandardError "ssh_err.txt"
                $Result.ExitCode = $Process.ExitCode
                $Result.Output = Get-Content "ssh_out.txt" -Raw -ErrorAction SilentlyContinue
                $Result.Error = Get-Content "ssh_err.txt" -Raw -ErrorAction SilentlyContinue
                Remove-Item "ssh_out.txt", "ssh_err.txt" -ErrorAction SilentlyContinue
            }
            else {
                $Process = Start-Process -FilePath "ssh" -ArgumentList $SshArgs -NoNewWindow -Wait -PassThru
                $Result.ExitCode = $Process.ExitCode
            }
            
            $Result.Duration = (Get-Date) - $AttemptStart
            
            if ($Process.ExitCode -eq 0) {
                $Result.Success = $true
                Write-ToolkitLog -Level "Debug" -Message "SSH command succeeded on attempt $Attempt" -Data @{command = $Command; duration = $Result.Duration.TotalSeconds }
                return $Result
            }
            
            $LastError = $Result.Error ?? "Exit code: $($Process.ExitCode)"
            Write-ToolkitLog -Level "Warn" -Message "SSH command failed (attempt $Attempt/$($RetryCount+1))" -Data @{command = $Command; exitCode = $Process.ExitCode; error = $LastError }
            
        }
        catch {
            $LastError = $_.ToString()
            Write-ToolkitLog -Level "Error" -Message "SSH command exception" -Data @{command = $Command; exception = $LastError }
        }
        
        if ($Attempt -le $RetryCount) {
            Write-ToolkitLog -Level "Info" -Message "Retrying in $RetryDelay seconds..." -Data @{attempt = $Attempt; maxAttempts = $RetryCount + 1 }
            Start-Sleep -Seconds $RetryDelay
        }
    }
    
    $TotalDuration = (Get-Date) - $StartTime
    Write-ToolkitLog -Level "Error" -Message "SSH command failed after $($RetryCount+1) attempts" -Data @{command = $Command; totalDuration = $TotalDuration.TotalSeconds; lastError = $LastError }
    
    return @{
        Success  = $false
        ExitCode = -1
        Output   = ""
        Error    = "Failed after $($RetryCount+1) attempts: $LastError"
        Duration = $TotalDuration.TotalSeconds
        Attempts = $RetryCount + 1
    }
}

function Invoke-SCPTransfer {
    <#
    .SYNOPSIS
        Transfers files via SCP with retry logic and structured error handling.
    .DESCRIPTION
        Transfers files via SCP with configurable retry logic, progress, and structured error objects.
    .PARAMETER Config
        Toolkit config containing IP, User, Key
    .PARAMETER Source
        Source path (local or remote)
    .PARAMETER Destination
        Destination path (local or remote)
    .PARAMETER RetryCount
        Number of retry attempts (default: 2)
    .PARAMETER RetryDelay
        Delay between retries in seconds (default: 2)
    .PARAMETER Recursive
        Whether to transfer recursively (default: $false)
    .RETURNS
        Hashtable with Success, ExitCode, Output, Error, Duration
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $Config,
        [Parameter(Mandatory = $true)]
        [string]$Source,
        [Parameter(Mandatory = $true)]
        [string]$Destination,
        [int]$RetryCount = 2,
        [int]$RetryDelay = 2,
        [switch]$Recursive
    )
    
    $C = Get-ToolkitColors
    $IP = $Config.IP
    $User = $Config.User
    $Key = $Config.Key
    $StartTime = Get-Date
    
    $ScpArgs = @("-i", $Key, "-o", "ConnectTimeout=30", "-o", "BatchMode=yes", "-o", "StrictHostKeyChecking=no")
    if ($Recursive) { $ScpArgs += "-r" }
    $ScpArgs += $Source
    $ScpArgs += $Destination
    
    $Attempt = 0
    $LastError = $null
    
    while ($Attempt -le $RetryCount) {
        $Attempt++
        $AttemptStart = Get-Date
        
        try {
            $Result = @{Success = $false; ExitCode = -1; Output = ""; Error = ""; Duration = 0 }
            
            $Process = Start-Process -FilePath "scp" -ArgumentList $ScpArgs -NoNewWindow -Wait -PassThru -RedirectStandardOutput "scp_out.txt" -RedirectStandardError "scp_err.txt"
            $Result.ExitCode = $Process.ExitCode
            $Result.Output = Get-Content "scp_out.txt" -Raw -ErrorAction SilentlyContinue
            $Result.Error = Get-Content "scp_err.txt" -Raw -ErrorAction SilentlyContinue
            Remove-Item "scp_out.txt", "scp_err.txt" -ErrorAction SilentlyContinue
            
            $Result.Duration = (Get-Date) - $AttemptStart
            
            if ($Process.ExitCode -eq 0) {
                $Result.Success = $true
                Write-ToolkitLog -Level "Debug" -Message "SCP transfer succeeded on attempt $Attempt" -Data @{source = $Source; destination = $Destination; duration = $Result.Duration.TotalSeconds }
                return $Result
            }
            
            $LastError = $Result.Error ?? "Exit code: $($Process.ExitCode)"
            Write-ToolkitLog -Level "Warn" -Message "SCP transfer failed (attempt $Attempt/$($RetryCount+1))" -Data @{source = $Source; destination = $Destination; exitCode = $Process.ExitCode; error = $LastError }
            
        }
        catch {
            $LastError = $_.ToString()
            Write-ToolkitLog -Level "Error" -Message "SCP transfer exception" -Data @{source = $Source; destination = $Destination; exception = $LastError }
        }
        
        if ($Attempt -le $RetryCount) {
            Write-ToolkitLog -Level "Info" -Message "Retrying in $RetryDelay seconds..." -Data @{attempt = $Attempt; maxAttempts = $RetryCount + 1 }
            Start-Sleep -Seconds $RetryDelay
        }
    }
    
    $TotalDuration = (Get-Date) - $StartTime
    Write-ToolkitLog -Level "Error" -Message "SCP transfer failed after $($RetryCount+1) attempts" -Data @{source = $Source; destination = $Destination; totalDuration = $TotalDuration.TotalSeconds; lastError = $LastError }
    
    return @{
        Success  = $false
        ExitCode = -1
        Output   = ""
        Error    = "Failed after $($RetryCount+1) attempts: $LastError"
        Duration = $TotalDuration.TotalSeconds
        Attempts = $RetryCount + 1
    }
}

function Mask-Secrets {
    <#
    .SYNOPSIS
        Masks sensitive data in log messages.
    .DESCRIPTION
        Replaces sensitive patterns (passwords, keys, tokens) with ***MASKED*** in text.
    .PARAMETER Text
        Text to sanitize
    .RETURNS
        Sanitized text
    #>
    [CmdletBinding()]
    param([string]$Text)
    
    if (-not $Text) { return $Text }
    
    # Mask SSH keys
    $MaskPattern = @'
["']?
'@
    $Text = $Text -replace "(?i)(-i\s+)$MaskPattern([^`"'\s]+)$MaskPattern", '$1***MASKED***'
    $Text = $Text -replace "(?i)(ssh\s+-i\s+)$MaskPattern([^`"'\s]+)$MaskPattern", '$1***MASKED***'
    
    # Mask passwords in URLs
    $Text = $Text -replace '(?i)(password|pwd|pass|secret|token|key)=([^&\s]+)', '$1=***MASKED***'
    
    # Mask private key content
    $Text = $Text -replace '-----BEGIN (?:RSA|DSA|EC|OPENSSH) PRIVATE KEY-----[\s\S]*?-----END (?:RSA|DSA|EC|OPENSSH) PRIVATE KEY-----', '-----BEGIN PRIVATE KEY-----***MASKED***-----END PRIVATE KEY-----'
    
    return $Text
}

function New-ToolkitError {
    <#
    .SYNOPSIS
        Creates a standardized error object.
    .DESCRIPTION
        Creates a consistent error object with code, message, category, and context.
    .PARAMETER Code
        Error code (e.g., 'SSH_CONNECTION_FAILED')
    .PARAMETER Message
        Human-readable error message
    .PARAMETER Category
        Error category (Connection, Authentication, Permission, Timeout, Validation, Internal)
    .PARAMETER Details
        Additional structured data
    .PARAMETER Config
        Toolkit config for context
    .RETURNS
        Standardized error object
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$Code,
        [Parameter(Mandatory = $true)][string]$Message,
        [ValidateSet('Connection', 'Authentication', 'Permission', 'Timeout', 'Validation', 'Internal')]
        [string]$Category = 'Internal',
        $Details = @{},
        $Config = $null
    )
    
    $ErrorObj = [PSCustomObject]@{
        Code       = $Code
        Message    = $Message
        Category   = $Category
        Details    = $Details
        Timestamp  = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        Context    = if ($Config) { $Config.IP } else { "LocalSystem" }
        StackTrace = (Get-PSCallStack | Select-Object -First 5 | ForEach-Object { $_.Command }) -join " -> "
    }
    
    Write-ToolkitLog -Level "Error" -Message "${Code}: $Message" -Data @{'code' = $Code; 'category' = $Category; 'details' = $Details } -Config $Config
    
    return $ErrorObj
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
    $C = Get-ToolkitColors

    if ($null -ne $Answer -and $Answer -ne "") {
        Write-ToolkitLog -Level "Debug" -Message "PROMPT: $Title : $Message → (injected) $Answer" -Config $null
        return $Answer
    }

    if ($env:TOOLKIT_PROMPT_DEFAULT) {
        Write-ToolkitLog -Level "Debug" -Message "PROMPT: $Title : $Message → (env) $env:TOOLKIT_PROMPT_DEFAULT" -Config $null
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
                Write-ToolkitLog -Level "Info" -Message "PROMPT: $Title : $Message → $Choice" -Config $null
                return $Choice
            }
        }
        catch {
            Write-ToolkitLog -Level "Warn" -Message "PROMPT: GUI unavailable, using console" -Config $null
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
    }
    catch {
        if ($Default) { return $Default } else { return $Buttons[0] }
    }
    try {
        $Sel = Read-Host "Choose (0-$($Buttons.Count - 1))"
    }
    catch {
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
    Write-Host "$($C.Crit)═══ $Header ═══$($C.Reset)"
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
        Write-Host "$($C.Ok)Confirmed.$($C.Reset)"
    }
    else {
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
    }
    catch {
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
            try { Invoke-ToolkitContextAction -Action "chain" -ForwardedArgs @("run", $Actions[$Choice]) } catch {
                Write-ToolkitError -Message "Interactive chain '$($Actions[$Choice])' failed: $_" -Config $Config
            }
        }
    }

    # Use new structured logging
    $LogLevel = switch ($Sev) {
        'debug' { 'Debug' }
        'info' { 'Info' }
        'warn' { 'Warn' }
        'error' { 'Error' }
        'critical' { 'Critical' }
        default { 'Info' }
    }
    Write-ToolkitLog -Level $LogLevel -Message "$Title : $Message" -Config $Config
    
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
        }
        else { Write-Host "[No matches for '$Term']" -ForegroundColor Red }
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
        }
        else {
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
        $ChildActions = Get-ChildItem "$ChildModulePath\Actions\*.ps1" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty BaseName
        $SharedActions = Get-ChildItem "$global:SharedToolkitPath\Actions\*.ps1" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty BaseName
        if ($ChildActions -or $SharedActions) {
            Write-Host ""
            Write-Host "Action Plugins:" -ForegroundColor Yellow
            foreach ($A in $ChildActions) { Write-Host "  $Caller $($C.Action)$A$($C.Reset) (SSH-specific)" }
            foreach ($A in $SharedActions) { Write-Host "  $Caller $($C.Action)$A$($C.Reset) (Shared)" }
        }
        $ChildList = Get-ChildItem "$ChildModulePath\Listeners\*.ps1" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty BaseName
        $SharedList = Get-ChildItem "$global:SharedToolkitPath\Listeners\*.ps1" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty BaseName
        if ($ChildList -or $SharedList) {
            Write-Host ""
            Write-Host "Listeners:" -ForegroundColor Yellow
            foreach ($L in $ChildList) { Write-Host "  $Caller $($C.List)$L$($C.Reset) (SSH-specific)" }
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
    <#
    .SYNOPSIS
        Executes an action belonging to another installed toolkit.

    .DESCRIPTION
        Resolves the target toolkit through PowerShell's module discovery
        instead of assuming a particular Documents\PowerShell\Modules path.
        The target action is invoked using the common Config/Arguments
        contract used by toolkit actions.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$Toolkit,
        [Parameter(Mandatory = $true)][string]$Action,
        [array]$Arguments = @(),
        $Config = $null
    )

    $ToolkitPath = Get-ToolkitInstallPath -ToolkitName $Toolkit
    if (-not $ToolkitPath) {
        Write-Host "No installed toolkit named '$Toolkit' was found on PSModulePath." -ForegroundColor Red
        return $false
    }

    $Action = Resolve-ToolkitActionName -Name $Action -ToolkitPath $ToolkitPath
    $ActionFile = Join-Path $ToolkitPath "Actions\$Action.ps1"

    if (-not (Test-Path -LiteralPath $ActionFile -PathType Leaf)) {
        Write-Host "Toolkit '$Toolkit' has no action '$Action'." -ForegroundColor Red
        return $false
    }

    try {
        # Import the target module so any shared dependencies and exported
        # router/helper functions are available. The action itself is invoked
        # directly because this is an explicit cross-toolkit action call.
        if (-not (Get-Module -Name $Toolkit)) {
            Import-Module $Toolkit -ErrorAction Stop
        }

        & $ActionFile -Config $Config -Arguments $Arguments
        return $true
    }
    catch {
        Write-ToolkitError -Message "Cross-toolkit action '$Toolkit::$Action' failed: $_" -Config $Config
        return $false
    }
}

function Get-ToolkitInstallPath {
    <#
    .SYNOPSIS
        Returns the on-disk directory of an installed toolkit module, resolved from
        PSModulePath wherever it was installed (default user path or a custom
        -Destination that is on PSModulePath).
    #>
    [CmdletBinding()]
    param([string]$ToolkitName)
    $m = Get-Module -ListAvailable -Name $ToolkitName -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -like '*Toolkit' } |
    Sort-Object Version -Descending | Select-Object -First 1
    if ($m) { return Split-Path -Parent $m.Path }
    return $null
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
    # Discover installed toolkits dynamically across PSModulePath (no hard-coded
    # list) so completion also covers new toolkits and custom -Destination installs.
    $Toolkits = @(Get-Module -ListAvailable |
        Where-Object { $_.Name -like '*Toolkit' } |
        Select-Object -Unique -ExpandProperty Name | Sort-Object)

    $AllAliases = @()
    foreach ($Toolkit in $Toolkits) {
        $ToolkitPath = Get-ToolkitInstallPath -ToolkitName $Toolkit
        $ProfilePath = Join-Path $ToolkitPath 'Profiles'
        if (-not $ToolkitPath -or -not (Test-Path $ProfilePath)) { continue }
        Get-ChildItem "$ProfilePath\*.json" -ErrorAction SilentlyContinue | ForEach-Object {
            $Alias = $_.BaseName
            $AllAliases += $Alias
            Register-ToolkitArgumentCompleter -AliasName $Alias -ToolkitName $Toolkit
        }
    }
    # SharedToolkit's generic dispatcher (e.g. `ani`) accepts -Action.
    # Register a single fallback Action completer. PowerShell keys completers by
    # CommandName+ParameterName (re-registration overwrites rather than stacks),
    # and we guard the flag anyway so re-sourcing the profile is a no-op.
    if (-not $script:__ToolkitSharedActionCompletionRegistered) {
        Register-ArgumentCompleter -CommandName 'ani' -ParameterName Action -ScriptBlock {
            param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameter)
            # Fallback - real completion comes from toolkit-specific completers above.
        } | Out-Null
        $script:__ToolkitSharedActionCompletionRegistered = $true
    }

    # Cross-toolkit dispatch completion for all profile aliases
    foreach ($Alias in $AllAliases) {
        Register-ArgumentCompleter -CommandName $Alias -ParameterName Action -ScriptBlock {
            param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameter)
            # Complete 'dispatch' subcommand
            if ($wordToComplete -like "d*") {
                "dispatch" | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object { [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_) }
            }
        } | Out-Null

        # Dispatch toolkit completion
        Register-ArgumentCompleter -CommandName $Alias -ParameterName Toolkit -ScriptBlock {
            param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameter)
            if ($fakeBoundParameter.Action -eq "dispatch" -or $fakeBoundParameter.Action -like "d*") {
                $Toolkits = @(Get-Module -ListAvailable | Where-Object { $_.Name -like '*Toolkit' } | Select-Object -Unique -ExpandProperty Name)
                $Toolkits | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object { [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_) }
            }
        } | Out-Null

        # Dispatch action completion based on selected toolkit
        Register-ArgumentCompleter -CommandName $Alias -ParameterName Action -ScriptBlock {
            param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameter)
            if ($fakeBoundParameter.Toolkit) {
                $ActionPath = Join-Path (Get-ToolkitInstallPath -ToolkitName $fakeBoundParameter.Toolkit) 'Actions'
                if (Test-Path $ActionPath) {
                    Get-ChildItem "$ActionPath\*.ps1" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty BaseName | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object { [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_) }
                }
            }
        } | Out-Null
    }

    # Chain completion
    Register-ArgumentCompleter -CommandName "chain" -ParameterName Action -ScriptBlock {
        param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameter)
        $Subs = @("list", "new", "run", "del", "delete", "show")
        $Subs | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object { [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_) }
    } | Out-Null

    Register-ArgumentCompleter -CommandName "chain" -ParameterName Name -ScriptBlock {
        param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameter)
        $ChainDirs = @(Get-ToolkitChainDirs)
        foreach ($d in $ChainDirs) {
            if (Test-Path $d) {
                Get-ChildItem "$d\*.json" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty BaseName | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object { [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_) }
            }
        }
    } | Out-Null

    # Format switch completion
    $FormatSwitches = @("-json", "-csv", "-raw", "-table", "-Force", "-f", "-DryRun", "-ConfirmAnswer", "-help", "-h", "-?")
    Register-ArgumentCompleter -CommandName "*" -ParameterName "*" -ScriptBlock {
        param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameter)
        if ($wordToComplete -like "-*") {
            $FormatSwitches | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object { [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_) }
        }
    } | Out-Null
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
        [Parameter(ValueFromPipeline = $true, Mandatory = $true)]
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
                }
                else {
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
                }
                else {
                    $Data | ForEach-Object { $_ -join ' | ' }
                }
            }
            default {
                if ($Properties) {
                    $Data | Format-Table -AutoSize -Property $Properties | Out-String
                }
                else {
                    $Data | Format-Table -AutoSize | Out-String
                }
            }
        }
    }
}

function Register-ToolkitArgumentCompleter {
    param([string]$AliasName, [string]$ToolkitName)
    $ToolkitDir = Get-ToolkitInstallPath -ToolkitName $ToolkitName
    $ActionNames = @(Get-ChildItem "$ToolkitDir\Actions\*.ps1" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty BaseName)
    $SubNames = @("config", "help", "online", "ssh", "chain", "history", "registry", "dispatch", "backup", "restore", "schedule", "theme", "alias", "events", "notify", "ask", "alert", "dashboard", "timer", "battery", "sys", "procs", "svc", "net", "hash", "find", "grep", "log", "beep", "toast", "speak", "open", "now", "clip", "shot")
    $AllActions = @($ActionNames + $SubNames) | Select-Object -Unique | Sort-Object
    Register-ArgumentCompleter -CommandName $AliasName -ParameterName Action -ScriptBlock {
        param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameter)
        $AllActions | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object { [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_) }
    } | Out-Null
}

function Invoke-PluginAction {
    <#
    .SYNOPSIS
        Global plugin management command.
    .DESCRIPTION
        Manages user plugins from ~/.toolkit/plugins/
    .PARAMETER Action
        Action to perform: list, load, unload, reload, info, new, run
    .PARAMETER PluginName
        Specific plugin name to operate on
    #>
    [CmdletBinding()]
    param(
        [ValidateSet('list', 'load', 'unload', 'reload', 'info', 'new', 'run')]
        [string]$Action = 'list',
        [string]$PluginName,
        [string]$PluginPath,
        [Parameter(ValueFromRemainingArguments)]
        [string[]]$PluginArgs,
        [switch]$Force
    )

    # ... rest of function
    $PluginRoot = "$env:USERPROFILE\.toolkit\plugins"
    $PluginManifest = "$PluginRoot\plugins.json"

    function Write-Step { param([string]$Message) Write-Host "`n[PLUGIN] $Message" -ForegroundColor Cyan }
    function Write-OK { param([string]$Message) Write-Host "  [OK] $Message" -ForegroundColor Green }
    function Write-Warn { param([string]$Message) Write-Host "  [WARN] $Message" -ForegroundColor Yellow }
    function Write-Err { param([string]$Message) Write-Host "  [ERR] $Message" -ForegroundColor Red }

    # Ensure plugin directory exists
    if (-not (Test-Path $PluginRoot)) {
        New-Item -ItemType Directory -Path $PluginRoot -Force | Out-Null
        Write-OK "Created plugin directory: $PluginRoot"
    }

    # Initialize manifest
    if (-not (Test-Path $PluginManifest)) {
        @{} | ConvertTo-Json | Out-File $PluginManifest -Force
    }

    function Discover-Plugins {
        $Plugins = @()
        if (Test-Path $PluginRoot) {
            Get-ChildItem "$PluginRoot\*.ps1" -ErrorAction SilentlyContinue | ForEach-Object {
                $Plugin = @{
                    Name        = $_.BaseName
                    Path        = $_.FullName
                    Version     = '1.0.0'
                    Description = ''
                    Author      = ''
                    Actions     = @()
                    Loaded      = $false
                }
                
                # Parse plugin header
                $Lines = Get-Content $_.FullName -Head 30 -ErrorAction SilentlyContinue
                foreach ($Line in $Lines) {
                    if ($Line -match '^#\s*Version:\s*(.+)$') { $Plugin.Version = $matches[1].Trim() }
                    elseif ($Line -match '^#\s*Description:\s*(.+)$') { $Plugin.Description = $matches[1].Trim() }
                    elseif ($Line -match '^#\s*Author:\s*(.+)$') { $Plugin.Author = $matches[1].Trim() }
                    elseif ($Line -match '^#\s*Action:\s*(.+)$') { $Plugin.Actions += $matches[1].Trim() }
                }
                
                $Plugins += [PSCustomObject]$Plugin
            }
        }
        return $Plugins
    }

    function Load-Plugin {
        param([string]$Name)
        $PluginPath = "$PluginRoot\$Name.ps1"
        if (-not (Test-Path $PluginPath)) {
            Write-Err "Plugin not found: $Name"
            return $false
        }
        try {
            $before = (Get-ChildItem Function:).Name
            . $PluginPath
            $after = (Get-ChildItem Function:).Name
            foreach ($fn in ($after | Where-Object { $_ -notin $before })) {
                try { Set-Item -Path "Function:Global\$fn" -Value (Get-Item "Function:\$fn").ScriptBlock -Force } catch {}
            }
            Write-OK "Loaded plugin: $Name"
            return $true
        }
        catch {
            Write-Err "Failed to load plugin '$Name': $_"
            return $false
        }
    }

    function Unload-Plugin {
        param([string]$Name)
        $PluginPath = "$PluginRoot\$Name.ps1"
        if (Test-Path $PluginPath) {
            $Content = Get-Content $PluginPath -Raw
            $Functions = [regex]::Matches($Content, 'function\s+(\w+)') | ForEach-Object { $_.Groups[1].Value }
            foreach ($Func in $Functions) {
                if (Get-Command $Func -ErrorAction SilentlyContinue) {
                    Remove-Item "Function:Global\$Func" -Force -ErrorAction SilentlyContinue
                }
            }
            Write-OK "Unloaded plugin: $Name"
        }
    }

    switch ($Action) {
        'list' {
            Write-Step "Discovering plugins in $PluginRoot"
            $Plugins = Discover-Plugins
            if ($Plugins.Count -eq 0) {
                Write-Warn "No plugins found. Create one with: plugin new myplugin"
            }
            else {
                $Plugins | Format-Table Name, Version, Description, Actions, Loaded -AutoSize
            }
        }
        
        'load' {
            if (-not $PluginName) { Write-Err "Usage: plugin load <name>"; return }
            Load-Plugin $PluginName
        }
        
        'unload' {
            if (-not $PluginName) { Write-Err "Usage: plugin unload <name>"; return }
            Unload-Plugin $PluginName
        }
        
        'reload' {
            if (-not $PluginName) { Write-Err "Usage: plugin reload <name>"; return }
            Unload-Plugin $PluginName
            Load-Plugin $PluginName
        }
        
        'info' {
            if (-not $PluginName) { Write-Err "Usage: plugin info <name>"; return }
            $PluginPath = "$PluginRoot\$PluginName.ps1"
            if (-not (Test-Path $PluginPath)) { Write-Err "Plugin not found: $PluginName"; return }
            
            $Content = Get-Content $PluginPath -Raw
            Write-Host "`nPlugin: $PluginName" -ForegroundColor Cyan
            Write-Host "Path: $PluginPath"
            
            $Lines = Get-Content $PluginPath -Head 50
            foreach ($Line in $Lines) {
                if ($Line -match '^#\s*(Version|Description|Author|Action):\s*(.+)$') {
                    Write-Host "  $($matches[1]): $($matches[2].Trim())" -ForegroundColor Gray
                }
            }
            
            $Functions = [regex]::Matches($Content, 'function\s+(\w+)') | ForEach-Object { $_.Groups[1].Value }
            if ($Functions) {
                Write-Host "`nActions: $($Functions -join ', ')" -ForegroundColor Yellow
            }
        }
        
        'new' {
            if (-not $PluginName) { Write-Err "Usage: plugin new <name>"; return }
            
            $PluginFile = "$PluginRoot\$PluginName.ps1"
            if (Test-Path $PluginFile -and -not $Force) {
                Write-Err "Plugin already exists: $PluginName (use -Force to overwrite)"
                return
            }
            
            $Template = @"
# Version: 1.0.0
# Description: $PluginName plugin
# Author: $env:USERNAME
# Action: $PluginName

function $PluginName {
    <#
    .SYNOPSIS
        $PluginName plugin action
    .DESCRIPTION
        User plugin. Edit the body to implement your feature.
    .PARAMETER Config
        Toolkit config object (may be `$null for local-only plugins)
    .PARAMETER Arguments
        Command arguments array
    #>
    [CmdletBinding()]
    param(
        `$Config,
        [array]`$Arguments
    )

    `$C = Get-ToolkitColors
    Write-Host "[$PluginName] Hello from plugin! Args: `$(`$Arguments -join ' ')" -ForegroundColor Cyan
}
"@
            
            $Template | Out-File $PluginFile -Encoding utf8
            Write-OK "Created plugin: $PluginFile"
            Write-Host "Edit the file to add your actions, then run: plugin load $PluginName"
        }
        
        'run' {
            if (-not $PluginName) { Write-Err "Usage: plugin run <name> [args...]"; return }
            $PluginPath = "$PluginRoot\$PluginName.ps1"
            if (-not (Test-Path $PluginPath)) { Write-Err "Plugin not found: $PluginName"; return }
            try {
                . $PluginPath
            }
            catch {
                Write-Err "Failed to load plugin '$PluginName': $_"; return
            }
            $ActionName = $null
            foreach ($l in (Get-Content $PluginPath -Head 10)) {
                if ($l -match '^#\s*Action:\s*(.+)$') { $ActionName = $matches[1].Trim(); break }
            }
            if (-not $ActionName) { $ActionName = $PluginName }
            if (Get-Command $ActionName -ErrorAction SilentlyContinue) {
                & $ActionName -Arguments $PluginArgs
            }
            else {
                Write-Err "Plugin entry function '$ActionName' not found."
            }
        }

        default {
            Write-Err "Unknown action: $Action"
            Write-Host "Available actions: list, load, unload, reload, info, new, run"
        }
    }
}

New-Alias -Name plugin -Value Invoke-PluginAction -Force -Scope Global
Export-ModuleMember -Function * -Alias plugin


