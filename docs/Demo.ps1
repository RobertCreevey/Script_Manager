<#
.SYNOPSIS
    Interactive demo of the Script_Manager toolkit ecosystem.

.DESCRIPTION
    Walks through every major feature with user-controlled pacing:
    profiles, help, config, dispatch, chains, aliases, and representative
    actions from each installed toolkit.

    Run modes:
      Interactive menu (default)
      Step-by-step with keypress
      Run all without pauses

.PARAMETER ProfileName
    Temporary profile name for this demo. Defaults to a unique demo name.

.PARAMETER StepByStep
    Pause after every action until the user presses Enter.

.PARAMETER All
    Run all sections non-interactively.

.EXAMPLE
    .\docs\Demo.ps1

.EXAMPLE
    .\docs\Demo.ps1 -StepByStep

.EXAMPLE
    .\docs\Demo.ps1 -All
#>

[CmdletBinding(DefaultParameterSetName='Interactive')]
param(
    [Parameter(ParameterSetName='Interactive')]
    [Parameter(ParameterSetName='StepByStep')]
    [string]$ProfileName = "demo_$(New-Guid)",

    [Parameter(ParameterSetName='StepByStep')]
    [switch]$StepByStep,

    [Parameter(ParameterSetName='All')]
    [switch]$All
)

$ErrorActionPreference = 'Stop'
Import-Module .\SharedToolkit\SharedToolkit.psd1 -Force -ErrorAction Stop
Import-Module .\SSHToolkit\SSHToolkit.psd1 -Force -ErrorAction Stop
Import-Module .\NetToolkit\NetToolkit.psd1 -Force -ErrorAction Stop
Import-Module .\DockerToolkit\DockerToolkit.psd1 -Force -ErrorAction Stop
Import-Module .\GitToolkit\GitToolkit.psd1 -Force -ErrorAction Stop

$C = Get-ToolkitColors
$DemoProfile = $ProfileName
$DemoIP = "127.0.0.1"
$DemoUser = $env:USERNAME
$DemoKey = "C:\keys\id_rsa"

function Write-Step { param([string]$Message) Write-Host "`n===== $Message =====" -ForegroundColor Cyan }
function Write-OK { param([string]$Message) Write-Host "  [OK] $Message" -ForegroundColor Green }
function Write-Warn { param([string]$Message) Write-Host "  [WARN] $Message" -ForegroundColor Yellow }
function Write-Info { param([string]$Message) Write-Host "  [INFO] $Message" -ForegroundColor DarkGray }

function SafeInvoke {
    param(
        [string]$Label,
        [scriptblock]$Script
    )
    Write-Info $Label
    try {
        & $Script
        Write-OK "$Label succeeded"
    } catch {
        Write-Warn "$Label failed: $_"
    }
}

function Pause {
    param([string]$Message = "Press Enter to continue...")
    Write-Host "`n$Message" -ForegroundColor DarkGray -NoNewline
    if ($StepByStep) {
        $null = $Host.UI.PromptForChoice('', '', @(@{Label='Continue'; Key='Enter'}), 0)
    } else {
        $null = Read-Host
    }
}

function Show-Menu {
    param([array]$Items)
    Write-Host "`nAvailable sections:" -ForegroundColor Cyan
    for ($i = 0; $i -lt $Items.Count; $i++) {
        Write-Host ("  {0}. {1}" -f ($i + 1), $Items[$i])
    }
    Write-Host "  A. Run all sections"
    Write-Host "  Q. Quit`n"
}

$Sections = @(
    'Profiles',
    'Help System',
    'Output Formats',
    'Cross-Toolkit Dispatch',
    'Alias Resolution',
    'Chains',
    'SharedToolkit Actions',
    'SSHToolkit Actions',
    'NetToolkit Actions',
    'DockerToolkit Actions',
    'GitToolkit Actions',
    'Plugin System'
)

# ---------------------------------------------------------------------------
# 1. Profiles
# ---------------------------------------------------------------------------
function Invoke-SectionProfiles {
    Write-Step "1. PROFILES"
    SafeInvoke -Label "Register profile '$DemoProfile'" -Script {
        Register-Target -Name $DemoProfile -IP $DemoIP -User $DemoUser -Key $DemoKey
    }
    SafeInvoke -Label "Profile alias resolution" -Script {
        $alias = Get-Alias $DemoProfile -ErrorAction SilentlyContinue
        if ($alias) { Write-Host "  Alias '$DemoProfile' -> $($alias.Definition)" }
    }
    SafeInvoke -Label "Invoke profile help" -Script {
        Invoke-Expression "$DemoProfile help" | Out-Null
    }
    SafeInvoke -Label "Profile config view" -Script {
        Invoke-Expression "$DemoProfile config view" | Out-Null
    }
    Pause
}

# ---------------------------------------------------------------------------
# 2. Help system
# ---------------------------------------------------------------------------
function Invoke-SectionHelp {
    Write-Step "2. HELP SYSTEM"
    SafeInvoke -Label "Invoke help-index toolkits" -Script {
        Invoke-Expression "$DemoProfile help-index toolkits" | Out-Null
    }
    SafeInvoke -Label "Invoke help-index actions" -Script {
        Invoke-Expression "$DemoProfile help-index actions" | Out-Null
    }
    SafeInvoke -Label "Invoke help find 'ssh'" -Script {
        Invoke-Expression "$DemoProfile help find ssh" | Out-Null
    }
    Pause
}

# ---------------------------------------------------------------------------
# 3. Output formats
# ---------------------------------------------------------------------------
function Invoke-SectionFormats {
    Write-Step "3. OUTPUT FORMATS"
    SafeInvoke -Label "Format JSON" -Script {
        $obj = @([PSCustomObject]@{Name = "Test"; Id = 1})
        $obj | Format-ToolOutput -Format json
    }
    SafeInvoke -Label "Format CSV" -Script {
        $obj = @([PSCustomObject]@{Name = "Test"; Id = 1})
        $obj | Format-ToolOutput -Format csv
    }
    SafeInvoke -Label "Format RAW" -Script {
        $dict = @{Name = "Test"; Id = 1}
        $dict | Format-ToolOutput -Format raw
    }
    SafeInvoke -Label "Format TABLE (default)" -Script {
        $obj = @([PSCustomObject]@{Name = "Test"; Id = 1})
        $obj | Format-ToolOutput
    }
    Pause
}

# ---------------------------------------------------------------------------
# 4. Cross-toolkit dispatch
# ---------------------------------------------------------------------------
function Invoke-SectionDispatch {
    Write-Step "4. CROSS-TOOLKIT DISPATCH"
    SafeInvoke -Label "Dispatch SharedToolkit toast" -Script {
        Invoke-Expression "$DemoProfile dispatch SharedToolkit toast 'Hello from dispatch'" | Out-Null
    }
    SafeInvoke -Label "Dispatch SharedToolkit sys" -Script {
        Invoke-Expression "$DemoProfile dispatch SharedToolkit sys" | Out-Null
    }
    Pause
}

# ---------------------------------------------------------------------------
# 5. Alias resolution
# ---------------------------------------------------------------------------
function Invoke-SectionAliases {
    Write-Step "5. ALIAS RESOLUTION"
    SafeInvoke -Label "Resolve GitToolkit alias 'st'" -Script {
        $r = Resolve-ToolkitActionName -Name "st" -ToolkitPath (Join-Path (Get-Location) 'GitToolkit')
        Write-Host "  Resolved 'st' -> $r"
    }
    SafeInvoke -Label "Resolve SharedToolkit 'chain'" -Script {
        $r = Resolve-ToolkitActionName -Name "chain" -ToolkitPath (Join-Path (Get-Location) 'GitToolkit')
        Write-Host "  Resolved 'chain' -> $r"
    }
    Pause
}

# ---------------------------------------------------------------------------
# 6. Chains
# ---------------------------------------------------------------------------
function Invoke-SectionChains {
    Write-Step "6. CHAINS"
    $ChainName = "demochain_$(New-Guid)"
    SafeInvoke -Label "Create chain '$ChainName'" -Script {
        Invoke-Expression "$DemoProfile chain new $ChainName SharedToolkit::toast 'From chain'" | Out-Null
    }
    SafeInvoke -Label "List chains" -Script {
        Invoke-Expression "$DemoProfile chain list" | Out-Null
    }
    SafeInvoke -Label "Run chain dry run" -Script {
        Invoke-Expression "$DemoProfile chain run $ChainName -DryRun" | Out-Null
    }
    SafeInvoke -Label "Run chain forced" -Script {
        Invoke-Expression "$DemoProfile chain run $ChainName -Force" | Out-Null
    }
    Pause
}

# ---------------------------------------------------------------------------
# 7. SharedToolkit actions
# ---------------------------------------------------------------------------
function Invoke-SectionShared {
    Write-Step "7. SHAREDTOOLKIT ACTIONS"
    SafeInvoke -Label "SharedToolkit sys" -Script {
        Invoke-Expression "$DemoProfile sys" | Out-Null
    }
    SafeInvoke -Label "SharedToolkit health" -Script {
        Invoke-Expression "$DemoProfile health" | Out-Null
    }
    SafeInvoke -Label "SharedToolkit hash" -Script {
        Invoke-Expression "$DemoProfile hash $PSCommandPath" | Out-Null
    }
    SafeInvoke -Label "SharedToolkit net" -Script {
        Invoke-Expression "$DemoProfile net" | Out-Null
    }
    SafeInvoke -Label "SharedToolkit battery" -Script {
        Invoke-Expression "$DemoProfile battery" | Out-Null
    }
    SafeInvoke -Label "SharedToolkit procs" -Script {
        Invoke-Expression "$DemoProfile procs -Top 5" | Out-Null
    }
    SafeInvoke -Label "SharedToolkit svc" -Script {
        Invoke-Expression "$DemoProfile svc -?" | Out-Null
    }
    SafeInvoke -Label "SharedToolkit clip" -Script {
        Invoke-Expression "$DemoProfile clip" | Out-Null
    }
    SafeInvoke -Label "SharedToolkit log" -Script {
        Invoke-Expression "$DemoProfile log 'demo event'" | Out-Null
    }
    SafeInvoke -Label "SharedToolkit history" -Script {
        Invoke-Expression "$DemoProfile history" | Out-Null
    }
    SafeInvoke -Label "SharedToolkit theme" -Script {
        Invoke-Expression "$DemoProfile theme" | Out-Null
    }
    SafeInvoke -Label "SharedToolkit alias list" -Script {
        Invoke-Expression "$DemoProfile alias" | Out-Null
    }
    SafeInvoke -Label "SharedToolkit events" -Script {
        Invoke-Expression "$DemoProfile events" | Out-Null
    }
    SafeInvoke -Label "SharedToolkit notify" -Script {
        Invoke-Expression "$DemoProfile notify test" | Out-Null
    }
    SafeInvoke -Label "SharedToolkit ask" -Script {
        Invoke-Expression "$DemoProfile ask -?" | Out-Null
    }
    SafeInvoke -Label "SharedToolkit alert" -Script {
        Invoke-Expression "$DemoProfile alert test" | Out-Null
    }
    SafeInvoke -Label "SharedToolkit dashboard" -Script {
        Invoke-Expression "$DemoProfile dashboard" | Out-Null
    }
    SafeInvoke -Label "SharedToolkit registry" -Script {
        Invoke-Expression "$DemoProfile registry" | Out-Null
    }
    SafeInvoke -Label "SharedToolkit backup list" -Script {
        Invoke-Expression "$DemoProfile backup list" | Out-Null
    }
    SafeInvoke -Label "SharedToolkit restore" -Script {
        Invoke-Expression "$DemoProfile restore" | Out-Null
    }
    SafeInvoke -Label "SharedToolkit schedule" -Script {
        Invoke-Expression "$DemoProfile schedule" | Out-Null
    }
    SafeInvoke -Label "SharedToolkit search 'test'" -Script {
        Invoke-Expression "$DemoProfile search test" | Out-Null
    }
    SafeInvoke -Label "SharedToolkit logs" -Script {
        Invoke-Expression "$DemoProfile logs" | Out-Null
    }
    SafeInvoke -Label "SharedToolkit profiles list" -Script {
        Invoke-Expression "$DemoProfile profiles list" | Out-Null
    }
    SafeInvoke -Label "SharedToolkit shell" -Script {
        Invoke-Expression "$DemoProfile shell -?" | Out-Null
    }
    SafeInvoke -Label "SharedToolkit chain list" -Script {
        Invoke-Expression "$DemoProfile chain list" | Out-Null
    }
    SafeInvoke -Label "SharedToolkit help-index" -Script {
        Invoke-Expression "$DemoProfile help-index" | Out-Null
    }
    SafeInvoke -Label "SharedToolkit open README" -Script {
        Invoke-Expression "$DemoProfile open README.md" | Out-Null
    }
    SafeInvoke -Label "SharedToolkit toast" -Script {
        Invoke-Expression "$DemoProfile toast 'Demo toast'" | Out-Null
    }
    SafeInvoke -Label "SharedToolkit beep" -Script {
        Invoke-Expression "$DemoProfile beep" | Out-Null
    }
    SafeInvoke -Label "SharedToolkit speak" -Script {
        Invoke-Expression "$DemoProfile speak 'Hello from demo'" | Out-Null
    }
    SafeInvoke -Label "SharedToolkit now" -Script {
        Invoke-Expression "$DemoProfile now" | Out-Null
    }
    SafeInvoke -Label "SharedToolkit shot" -Script {
        Invoke-Expression "$DemoProfile shot" | Out-Null
    }
    SafeInvoke -Label "SharedToolkit timer 1" -Script {
        Invoke-Expression "$DemoProfile timer 1" | Out-Null
    }
    SafeInvoke -Label "SharedToolkit speak 'Done'" -Script {
        Invoke-Expression "$DemoProfile speak 'Demo complete'" | Out-Null
    }
    Pause
}

# ---------------------------------------------------------------------------
# 8. SSHToolkit actions (local-only previews)
# ---------------------------------------------------------------------------
function Invoke-SectionSSH {
    Write-Step "8. SSHTOOLKIT ACTIONS (local previews)"
    SafeInvoke -Label "SSHToolkit help" -Script {
        Invoke-Expression "$DemoProfile help" | Out-Null
    }
    SafeInvoke -Label "SSHToolkit config view" -Script {
        Invoke-Expression "$DemoProfile config view" | Out-Null
    }
    SafeInvoke -Label "SSHToolkit apps" -Script {
        Invoke-Expression "$DemoProfile apps" | Out-Null
    }
    SafeInvoke -Label "SSHToolkit disk" -Script {
        Invoke-Expression "$DemoProfile disk" | Out-Null
    }
    SafeInvoke -Label "SSHToolkit ports" -Script {
        Invoke-Expression "$DemoProfile ports" | Out-Null
    }
    SafeInvoke -Label "SSHToolkit process" -Script {
        Invoke-Expression "$DemoProfile process" | Out-Null
    }
    SafeInvoke -Label "SSHToolkit service" -Script {
        Invoke-Expression "$DemoProfile service" | Out-Null
    }
    SafeInvoke -Label "SSHToolkit time" -Script {
        Invoke-Expression "$DemoProfile time" | Out-Null
    }
    Pause
}

# ---------------------------------------------------------------------------
# 9. NetToolkit actions (local-safe)
# ---------------------------------------------------------------------------
function Invoke-SectionNet {
    Write-Step "9. NETTOOLKIT ACTIONS"
    SafeInvoke -Label "NetToolkit publicip" -Script {
        Invoke-Expression "$DemoProfile dispatch NetToolkit publicip" | Out-Null
    }
    SafeInvoke -Label "NetToolkit gateway" -Script {
        Invoke-Expression "$DemoProfile dispatch NetToolkit gateway" | Out-Null
    }
    SafeInvoke -Label "NetToolkit dns google.com" -Script {
        Invoke-Expression "$DemoProfile dispatch NetToolkit dns google.com" | Out-Null
    }
    SafeInvoke -Label "NetToolkit arp" -Script {
        Invoke-Expression "$DemoProfile dispatch NetToolkit arp" | Out-Null
    }
    SafeInvoke -Label "NetToolkit connections" -Script {
        Invoke-Expression "$DemoProfile dispatch NetToolkit connections" | Out-Null
    }
    SafeInvoke -Label "NetToolkit macvendor 00-00-00-00-00-00" -Script {
        Invoke-Expression "$DemoProfile dispatch NetToolkit macvendor 00-00-00-00-00-00" | Out-Null
    }
    Pause
}

# ---------------------------------------------------------------------------
# 10. DockerToolkit actions (local-safe list)
# ---------------------------------------------------------------------------
function Invoke-SectionDocker {
    Write-Step "10. DOCKERTOOLKIT ACTIONS"
    SafeInvoke -Label "DockerToolkit system" -Script {
        Invoke-Expression "$DemoProfile dispatch DockerToolkit system" | Out-Null
    }
    SafeInvoke -Label "DockerToolkit ps" -Script {
        Invoke-Expression "$DemoProfile dispatch DockerToolkit ps" | Out-Null
    }
    SafeInvoke -Label "DockerToolkit images" -Script {
        Invoke-Expression "$DemoProfile dispatch DockerToolkit images" | Out-Null
    }
    SafeInvoke -Label "DockerToolkit volumes" -Script {
        Invoke-Expression "$DemoProfile dispatch DockerToolkit volumes" | Out-Null
    }
    SafeInvoke -Label "DockerToolkit networks" -Script {
        Invoke-Expression "$DemoProfile dispatch DockerToolkit networks" | Out-Null
    }
    Pause
}

# ---------------------------------------------------------------------------
# 11. GitToolkit actions (local-safe)
# ---------------------------------------------------------------------------
function Invoke-SectionGit {
    Write-Step "11. GITTOOLKIT ACTIONS"
    SafeInvoke -Label "GitToolkit status" -Script {
        Invoke-Expression "$DemoProfile dispatch GitToolkit status" | Out-Null
    }
    SafeInvoke -Label "GitToolkit log" -Script {
        Invoke-Expression "$DemoProfile dispatch GitToolkit log -n 5" | Out-Null
    }
    SafeInvoke -Label "GitToolkit remote" -Script {
        Invoke-Expression "$DemoProfile dispatch GitToolkit remote" | Out-Null
    }
    SafeInvoke -Label "GitToolkit branch" -Script {
        Invoke-Expression "$DemoProfile dispatch GitToolkit branch" | Out-Null
    }
    Pause
}

# ---------------------------------------------------------------------------
# 12. Plugin system
# ---------------------------------------------------------------------------
function Invoke-SectionPlugins {
    Write-Step "12. PLUGIN SYSTEM"
    SafeInvoke -Label "plugin list" -Script {
        Invoke-Expression "$DemoProfile plugin list" | Out-Null
    }
    SafeInvoke -Label "plugin new demoplugin" -Script {
        Invoke-Expression "$DemoProfile plugin new demoplugin" | Out-Null
    }
    SafeInvoke -Label "plugin info demoplugin" -Script {
        Invoke-Expression "$DemoProfile plugin info demoplugin" | Out-Null
    }
    Pause
}

# ---------------------------------------------------------------------------
# Cleanup
# ---------------------------------------------------------------------------
function Invoke-SectionCleanup {
    Write-Step "CLEANUP"
    SafeInvoke -Label "Remove demo profile" -Script {
        $p = Join-Path (Get-Location) "SSHToolkit\Profiles\$DemoProfile.json"
        if (Test-Path $p) { Remove-Item $p -Force }
        if (Get-Alias $DemoProfile -ErrorAction SilentlyContinue) { Remove-Item Alias:\$DemoProfile -Force }
    }
    SafeInvoke -Label "Remove demo chain" -Script {
        $chainFile = Join-Path (Get-Location) "SharedToolkit\Chains\$ChainName.json"
        if (Test-Path $chainFile) { Remove-Item $chainFile -Force }
    }
}

# ---------------------------------------------------------------------------
# Main interactive loop
# ---------------------------------------------------------------------------
if ($All) {
    Write-Host "`nRunning all sections non-interactively..." -ForegroundColor Yellow
    Invoke-SectionProfiles
    Invoke-SectionHelp
    Invoke-SectionFormats
    Invoke-SectionDispatch
    Invoke-SectionAliases
    Invoke-SectionChains
    Invoke-SectionShared
    Invoke-SectionSSH
    Invoke-SectionNet
    Invoke-SectionDocker
    Invoke-SectionGit
    Invoke-SectionPlugins
    Invoke-SectionCleanup
    Write-Host "`n[Done] Demo complete." -ForegroundColor Green
    exit 0
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host " Script_Manager Interactive Demo" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ("Profile : {0}" -f $DemoProfile)
Write-Host ("User    : {0}" -f $DemoUser)
Write-Host ("IP      : {0}" -f $DemoIP)

$script:ChainName = $null
$choice = ''
while ($choice -notmatch '^[Qq]$') {
    Show-Menu -Items $Sections
    $choice = Read-Host "Select a section number, A for all, or Q to quit"

    switch ($choice.ToUpper()) {
        'Q' { break }
        'A' {
            $Sections | ForEach-Object {
                Invoke-SectionProfiles
                Invoke-SectionHelp
                Invoke-SectionFormats
                Invoke-SectionDispatch
                Invoke-SectionAliases
                Invoke-SectionChains
                Invoke-SectionShared
                Invoke-SectionSSH
                Invoke-SectionNet
                Invoke-SectionDocker
                Invoke-SectionGit
                Invoke-SectionPlugins
            }
            Invoke-SectionCleanup
            break
        }
        default {
            if ([int]::TryParse($choice, [ref]$null) -and $choice -gt 0 -and $choice -le $Sections.Count) {
                $idx = [int]$choice - 1
                switch ($idx) {
                    0 { Invoke-SectionProfiles }
                    1 { Invoke-SectionHelp }
                    2 { Invoke-SectionFormats }
                    3 { Invoke-SectionDispatch }
                    4 { Invoke-SectionAliases }
                    5 { Invoke-SectionChains }
                    6 { Invoke-SectionShared }
                    7 { Invoke-SectionSSH }
                    8 { Invoke-SectionNet }
                    9 { Invoke-SectionDocker }
                    10 { Invoke-SectionGit }
                    11 { Invoke-SectionPlugins }
                }
            } else {
                Write-Warn "Invalid selection. Enter a number 1-$($Sections.Count), A, or Q."
            }
        }
    }
}

Invoke-SectionCleanup
Write-Host "`n[Done] Demo complete." -ForegroundColor Green
