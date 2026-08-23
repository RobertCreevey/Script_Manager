
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

# In-memory event ring buffer + persistent log path.
$global:ToolEvents = [System.Collections.ArrayList]::new()
$global:ToolEventLog = "$env:USERPROFILE\Documents\SSHToolkit_Events.log"

# Module-level safety net: any unhandled terminating error is recorded as an event.
trap {
    try { Invoke-ToolError -Message "Unhandled exception: $_" -Severity Critical } catch {}
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

function Invoke-ToolEvent {
    param([string]$Name, $Data = $null, $Config = $null)
    $Ev = [PSCustomObject]@{
        Time    = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Name    = $Name
        Context = if ($Config) { $Config.IP } else { "LocalSystem" }
        Data    = $Data
    }
    [void]$global:ToolEvents.Add($Ev)
    if ($global:ToolEvents.Count -gt 200) { $global:ToolEvents.RemoveAt(0) }
    $Line = "[$($Ev.Time)] [EVENT] [$($Ev.Context)] $($Ev.Name)$(if ($Ev.Data) { ' : ' + $Ev.Data })"
    try { $Line | Out-File $global:ToolEventLog -Append } catch {}
    $Ev
}

function Invoke-ToolError {
    param([string]$Message, [string]$Severity = "Error", $Config = $null)
    $C = $global:ToolColors
    $Ctx = if ($Config) { $Config.IP } else { "LocalSystem" }
    Write-Host "$($C.Warn)[$Severity]$($C.Reset) $Message" -ForegroundColor Red
    $LogLine = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$Ctx] [ERROR] $Message"
    try { $LogLine | Out-File $global:ToolEventLog -Append } catch {}
    Invoke-ToolEvent -Name "Error" -Data "$Severity : $Message" -Config $Config
    try { & "$global:SharedToolkitPath\Actions\toast.ps1" -Config $Config -Arguments @("Error", $Message) } catch {}
}

function Invoke-ToolNotify {
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
        $Buttons = ($Actions.Keys -join ",")
        $ChainMap = ($Actions.GetEnumerator() | ForEach-Object { "$($_.Key):$($_.Value)" }) -join ";"
        $AskArgs = @($Message, "$Severity : $Title", $Buttons, $ChainMap)
        try { & "$global:SharedToolkitPath\Actions\ask.ps1" -Config $Config -Arguments $AskArgs } catch {}
    }

    Write-Host "$($C.Info)[NOTIFY]$($C.Reset) ($Severity) $Title : $Message" -ForegroundColor Cyan
    Invoke-ToolEvent -Name "Notify" -Data "$Severity : $Title - $Message" -Config $Config
}

function Invoke-SharedHelpSystem {
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

function Invoke-SharedAsset {
    [CmdletBinding()]
    param([string]$Type, [string]$AssetName, $Config, $ForwardedArgs)
    $TargetScript = "$global:SharedToolkitPath\$Type\$AssetName.ps1"
    if (Test-Path $TargetScript) {
        & $TargetScript -Config $Config -Arguments $ForwardedArgs
        return $true
    }
    return $false
}

Export-ModuleMember -Function Invoke-SharedAsset, Invoke-SharedHelpSystem, Invoke-ToolEvent, Invoke-ToolError, Invoke-ToolNotify, Get-ToolStatus
