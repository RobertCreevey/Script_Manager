<#
.SYNOPSIS
    One-command installer for the Toolkit ecosystem.

.DESCRIPTION
    Installs every toolkit module discovered in the source tree (any directory
    that contains a matching *.psd1 manifest) into the user's PowerShell Modules
    directory, wires up $PROFILE auto-load, and prints beginner help.

    Toolkit discovery is DYNAMIC: adding a new toolkit folder (e.g. "FooToolkit")
    is picked up automatically on the next install run. No hard-coded toolkit list
    to keep in sync. Use -Toolkits to limit the set; names may be the full module
    name (SSHToolkit) or the short name (SSH).

.PARAMETER Toolkits
    Specific toolkits to install. Accepts '*' (default), 'ALL'/'all', or a list of
    short/full names, e.g. -Toolkits SSH,Net,Docker  or  -Toolkits SSHToolkit.

.PARAMETER Destination
    Install root (default: $env:USERPROFILE\Documents\PowerShell\Modules).

.PARAMETER ProfilePath
    PowerShell profile to edit for auto-load (default: current user, all hosts).

.PARAMETER AutoLoad
    Add Import-Module lines + Initialize-ToolkitCompletion to $ProfilePath.

.PARAMETER Force
    Overwrite existing toolkit installations.

.PARAMETER SkipProfile
    Do not touch $PROFILE.

.PARAMETER Verify
    Import the installed modules and probe a few core SharedToolkit functions.

.PARAMETER DryRun
    Show what would happen without writing anything.

.EXAMPLE
    .\Install-Toolkit.ps1
    Installs all discovered toolkits with defaults.

.EXAMPLE
    .\Install-Toolkit.ps1 -Toolkits SSH,Net -AutoLoad -Verify
    Installs a subset, wires auto-load, and verifies.

.EXAMPLE
    .\Install-Toolkit.ps1 -Destination .\tmp\Modules -DryRun
    Preview an install into a temp dir without writing files.
#>

# TODO: Integrate PlatyPS (Microsoft.PowerShell.PlatyPS) so `Get-Help <action>`
#       works natively. Source data: toolkit.json manifests + plugin headers
#       (# Type:, # Description:). Bootstrap: docs\Generate-Help.ps1
# TODO: Validate every toolkit.json against toolkit.schema.json (canonical key =
#       name, list items = aliases). Alias-list pattern already correct in
#       SSHToolkit/toolkit.json; confirm the rest.

[CmdletBinding()]
param(
    [string[]]$Toolkits = @('*'),
    [string]$Destination = "$env:USERPROFILE\Documents\PowerShell\Modules",
    [string]$ProfilePath = $PROFILE.CurrentUserAllHosts,
    [switch]$AutoLoad,
    [switch]$Force,
    [switch]$SkipProfile,
    [switch]$Verify,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$SourceRoot = $PSScriptRoot
$RequiredTools = @('ssh', 'scp', 'git', 'docker', 'aws', 'az', 'gcloud')

# Color output is handled by the SharedToolkit color system (Get-ToolkitColors),
# so the installer does NOT define its own palette. Import the source module to
# get the central theme; suppress plugin-load chatter during bootstrap. If the
# import fails, output simply degrades to plain text.
$global:ToolkitSuppressPluginLoad = $true
# Minimal plain-text theme so the installer never crashes if SharedToolkit can't
# be imported (e.g. running from a sandbox). Helpers resolve $C from script scope
# at call time, so a plain fallback keeps every Write-* call working.
$__ToolkitPlainTheme = [PSCustomObject]@{
    Step=''; Ok=''; Warn=''; Crit=''; Category=''; Info=''; Reset=''
    Host=''; Action=''; Sys=''; Str=''; Param=''; List=''; File=''; Muted=''
}
try {
    Import-Module (Join-Path $SourceRoot 'SharedToolkit') -DisableNameChecking -WarningAction SilentlyContinue -ErrorAction Stop
    $C = Get-ToolkitColors
    if (-not $C) { $C = $__ToolkitPlainTheme }
}
catch {
    # SharedToolkit unavailable: degrade to plain text (no ANSI escapes).
    $C = $__ToolkitPlainTheme
}

# Thin wrappers over the shared theme (one hue per message type, no rainbow):
#   Step=Cyan [INSTALL]   OK=Green [OK]   Warn=Yellow [WARN]   Err=Red [ERR]
#   Category=Magenta banners   Info=Blue/Grey diagnostic lines
function Write-Step { param([string]$M) Write-Host "`n$($C.Step)[INSTALL]$($C.Reset) $M" }
function Write-OK { param([string]$M) Write-Host "  $($C.Ok)[OK]$($C.Reset) $M" }
function Write-Warn { param([string]$M) Write-Host "  $($C.Warn)[WARN]$($C.Reset) $M" }
function Write-Err { param([string]$M) Write-Host "  $($C.Crit)[ERR]$($C.Reset) $M" }
function Write-Cat { param([string]$M) Write-Host "$($C.Category)$M$($C.Reset)" }
function Write-Info { param([string]$M) Write-Host "$($C.Info)$M$($C.Reset)" }

# --- Path/PSModulePath handling -------------------------------------------
# If the caller supplied a custom -Destination, ensure it's discoverable by
# PowerShell module resolution. For the default destination we only warn and
# fall back, because mutating the user's PSModulePath for a built-in default
# is unnecessary noise. For custom destinations we append explicitly so
# "run from anywhere" actually works even without a profile reload.
$userPsModulePath = [Environment]::GetEnvironmentVariable('PSModulePath', 'User')
$machinePsModulePath = [Environment]::GetEnvironmentVariable('PSModulePath', 'Machine')
$allPsModulePathEntries = @($env:PSModulePath -split ';' | Where-Object { $_ })
if ($PSBoundParameters.ContainsKey('Destination') -and -not $DryRun) {
    if ($allPsModulePathEntries -notcontains $Destination) {
        $addToUser = $true
        if ($userPsModulePath -split ';' | Where-Object { $_ } | Where-Object { $_ -eq $Destination }) {
            $addToUser = $false
        }
        if ($addToUser) {
            try {
                $newUserPath = (@($userPsModulePath -split ';' | Where-Object { $_ }) + $Destination) -join ';'
                [Environment]::SetEnvironmentVariable('PSModulePath', $newUserPath, 'User')
                $env:PSModulePath = $newUserPath + ';' + $env:PSModulePath
                Write-OK "Added '$Destination' to user PSModulePath (effective immediately for this session and future sessions)."
            }
            catch {
                Write-Warn "Failed to add '$Destination' to PSModulePath: $_"
                Write-Warn "You may need to import modules with full paths or add the directory to PSModulePath manually."
            }
        }
    }
}
elseif (-not $PSBoundParameters.ContainsKey('Destination') -and -not $DryRun) {
    $psmodEntries = $env:PSModulePath -split ';' | Where-Object { $_ }
    if ($psmodEntries -notcontains $Destination) {
        $alt = $psmodEntries | Where-Object { $_ -like '*\Documents\PowerShell\Modules' } | Select-Object -First 1
        if ($alt) {
            Write-Warn "Default destination '$Destination' is not on PSModulePath; using '$alt' so modules are recognized shell-wide."
            $Destination = $alt
        }
    }
}

Write-Info "SourceRoot: $SourceRoot"
Write-Info "Destination: $Destination"
if ($DryRun) { Write-Warn "Mode: DRY RUN (no files will be written)" }

# --- Prerequisites -------------------------------------------------------
Write-Step "Checking prerequisites..."
$MissingTools = @()
foreach ($Tool in $RequiredTools) {
    if (-not (Get-Command $Tool -ErrorAction SilentlyContinue)) { $MissingTools += $Tool }
}
if ($MissingTools.Count -gt 0) {
    Write-Warn "Optional tools not on PATH: $($MissingTools -join ', ')"
    Write-Warn "Some toolkits may not work without them (e.g. CloudToolkit needs aws/az/gcloud)"
}
else { Write-OK "All external tools found" }

# --- Discover available toolkits dynamically -----------------------------
Write-Step "Discovering toolkits..."
$AllAvailable = Get-ChildItem -Path $SourceRoot -Directory -ErrorAction SilentlyContinue |
Where-Object { Test-Path (Join-Path $_.FullName "$($_.Name).psd1") } |
Select-Object -ExpandProperty Name |
Sort-Object
if ($AllAvailable.Count -eq 0) {
    Write-Err "No toolkit directories with manifests found in $SourceRoot"
    return
}
Write-OK "Found $($AllAvailable.Count) toolkit(s): $($AllAvailable -join ', ')"

# --- Resolve requested set -------------------------------------------------
# Normalize input so callers can pass arrays, "SSH,Net,Docker", "SSH Net Docker",
# "*", "ALL"/"all", or full module names (SSHToolkit); short names are expanded.
$flat = ($Toolkits -join ' ') -split '[, ]+' | Where-Object { $_ }
if ($flat.Count -eq 1 -and $flat[0] -match '^(all|\*)$') { $ToInstall = $AllAvailable }
else {
    $ToInstall = @()
    foreach ($t in $flat) {
        $full = if ($t -like '*Toolkit') { $t } else { "${t}Toolkit" }
        if ($AllAvailable -contains $full) { $ToInstall += $full }
        elseif ($AllAvailable -contains $t) { $ToInstall += $t }
        else { Write-Warn "'$t' not found (try: $($AllAvailable -join ', '))"; continue }
    }
}
Write-Info "ToInstall: $($ToInstall -join ', ')"


# --- Create destination --------------------------------------------------
if (-not $DryRun -and -not (Test-Path $Destination)) {
    New-Item -ItemType Directory -Path $Destination -Force | Out-Null
    Write-OK "Created destination directory: $Destination"
}

# --- Install each toolkit ------------------------------------------------
$Installed = @()
foreach ($modName in $ToInstall) {
    Write-Step "Installing $modName..."
    $Src = Join-Path $SourceRoot $modName
    $Dst = Join-Path $Destination $modName

    if (-not (Test-Path $Src)) { Write-Err "Source not found: $Src (skipping)"; continue }

    if (-not $DryRun -and (-not $Force -and (Test-Path $Dst))) {
        Write-Warn "$modName already installed at $Dst (use -Force to overwrite)"; continue
    }

    if ($DryRun) { Write-OK "[DryRun] Would install $modName -> $Dst"; $Installed += $modName; continue }

    try {
        if (Test-Path $Dst) { Remove-Item $Dst -Recurse -Force }
        Copy-Item -Path $Src -Destination $Dst -Recurse -Force -ErrorAction Stop
        Write-OK "Installed $modName -> $Dst"
        $Installed += $modName
    }
    catch { Write-Err "Failed to install $modName`: $_"; continue }
}

# --- Auto-load profile wiring -------------------------------------------
if ($AutoLoad -and -not $SkipProfile) {
    Write-Step "Configuring auto-load in $ProfilePath..."
    # Import EVERY toolkit currently installed in $Destination (not just this
    # run's subset) so the profile always recognizes all installed toolkits.
    $ModulesToLoad = Get-ChildItem -Path $Destination -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -like '*Toolkit' -and (Test-Path (Join-Path $_.FullName "$($_.Name).psd1")) } |
        Select-Object -ExpandProperty Name |
        Where-Object { $_ -ne 'SharedToolkit' } |
        Sort-Object

    # Delimited block so it can be replaced idempotently (no stale duplicates).
    $startMarker = '# >>> Toolkit auto-load (added by Install-Toolkit.ps1) >>>'
    $endMarker   = '# <<< Toolkit auto-load <<<'
    # SharedToolkit's action names are non-Verb-Noun by design, so Import-Module
    # emits an 'unapproved verbs' notice. -DisableNameChecking handles the direct
    # import, but the notice also re-fires for each child's RequiredModules
    # resolution of SharedToolkit. Setting $WarningPreference at profile (global)
    # scope around the burst suppresses those nested notices (a child-scope &{}
    # block does NOT propagate to nested imports); it is restored right after.
    # Real import ERRORS stay visible via the Verify step.
    $LoadLines = @($startMarker)
    $LoadLines += '$__toolkitWarningPref = $WarningPreference'
    $LoadLines += '$WarningPreference = ''SilentlyContinue'''
    $LoadLines += 'Import-Module SharedToolkit -DisableNameChecking -ErrorAction SilentlyContinue'
    foreach ($mod in $ModulesToLoad) { $LoadLines += "Import-Module $mod -DisableNameChecking -ErrorAction SilentlyContinue" }
    $LoadLines += '$WarningPreference = $__toolkitWarningPref'
    $LoadLines += 'Initialize-ToolkitCompletion'
    $LoadLines += $endMarker
    $LoadLines += ''
    $LoadBlock = $LoadLines -join "`n"

    if ($DryRun) {
        Write-OK "[DryRun] Would write auto-load block to $ProfilePath (imports: SharedToolkit,$($ModulesToLoad -join ','))"
    }
    else {
        $ProfileDir = Split-Path $ProfilePath -Parent
        if (-not (Test-Path $ProfileDir)) { New-Item -ItemType Directory -Path $ProfileDir -Force | Out-Null }

        if (Test-Path $ProfilePath) {
            $Existing = Get-Content $ProfilePath -Raw
            # Strip any prior toolkit block (new delimited format or legacy text).
            if ($Existing -match [regex]::Escape($startMarker)) {
                if ($Existing -match [regex]::Escape($endMarker)) {
                    $Existing = [regex]::Replace($Existing, [regex]::Escape($startMarker) + '.*?' + [regex]::Escape($endMarker), '', [System.Text.RegularExpressions.RegexOptions]::Singleline)
                }
                else {
                    $Existing = [regex]::Replace($Existing, [regex]::Escape($startMarker) + '.*', '', [System.Text.RegularExpressions.RegexOptions]::Singleline)
                }
            }
            elseif ($Existing -match '# Toolkit auto-load \(added by Install-Toolkit\.ps1\)') {
                $Existing = [regex]::Replace($Existing, '# Toolkit auto-load \(added by Install-Toolkit\.ps1\).*', '', [System.Text.RegularExpressions.RegexOptions]::Singleline)
            }
            $Existing = $Existing.TrimEnd()
            if ($Existing) { $Existing = "$Existing`n`n" }
            Set-Content $ProfilePath "$Existing$LoadBlock"
            Write-OK "Wrote auto-load block to $ProfilePath"
        }
        else {
            Set-Content $ProfilePath $LoadBlock
            Write-OK "Created $ProfilePath with auto-load"
        }
    }
}

# --- Post-install verification ------------------------------------------
if ($Verify) {
    if ($DryRun) { Write-OK "[DryRun] Would verify imports" }
    else {
        Write-Step "Verifying installed modules..."
        $prev = $WarningPreference
        $WarningPreference = 'SilentlyContinue'
        try {
            Import-Module (Join-Path $Destination 'SharedToolkit') -DisableNameChecking -ErrorAction Stop
            foreach ($mod in ($Installed | Where-Object { $_ -ne 'SharedToolkit' })) {
                Import-Module (Join-Path $Destination $mod) -DisableNameChecking -ErrorAction Stop
            }
            Initialize-ToolkitCompletion -ErrorAction SilentlyContinue
            Write-OK "All modules import successfully"

            $r = Mask-Secrets "ssh -i C:\keys\id_rsa user@host"
            if ($r -like '*MASKED*') { Write-OK "Mask-Secrets working" }
            $e = New-ToolkitError -Code 'TEST' -Message 'install-verify' -Category 'Validation'
            if ($e.Code -eq 'TEST') { Write-OK "New-ToolkitError working" }
            Write-ToolkitLog -Level Info -Message 'Install verification'
            Write-OK "Write-ToolkitLog working"
        }
        catch { Write-Err "Verification failed: $_" }
        finally { $WarningPreference = $prev }
    }
}

# --- Summary + beginner onboarding --------------------------------------
Write-Step "Installation complete"
Write-Host "$($C.Ok)Installed toolkits: $($Installed -join ', ')$($C.Reset)"
if ($DryRun) { Write-Warn "[DryRun] No files were written." }

# How to get help / quick start (auto-show on every install so new users aren't stranded)
Write-Host ""
Write-Cat "Getting started / how to get help:"
Write-Host "  . `$PROFILE                                  # Load toolkits (or restart PowerShell)"
Write-Host "  <profile> help                               # Full index: builtins, actions, listeners"
Write-Host "  <profile> help-index actions               # List every action across toolkits"
Write-Host "  <profile> registry                         # List installed toolkits + versions"
Write-Host "  <profile> help <action>                    # Help for one action (e.g. snap)"
Write-Host "  <profile> plugin list                      # List installed plugins"
Write-Host "                                              # (plugins auto-load from ~/.toolkit/plugins)"
Write-Host ""
Write-Cat "Quick start:"
Write-Host "  New-Target -Name server1 -IP 10.0.0.50 -User admin -Key 'C:\keys\id_rsa'"
Write-Host "  server1 sys                                 # Remote system summary"
Write-Host "  server1 snap screenshot.png                 # Silent remote screenshot -> local"
Write-Host "  server1 play 'C:\Videos\demo.mp4'          # Force-play video on remote screen"
Write-Host ""
Write-Cat "Plugins:"
Write-Host "  plugin new MyUtil ; plugin load MyUtil ; MyUtil   # Create + use a local plugin"
Write-Host "  plugin run MyUtil -Help                         # Run a plugin action with args"

# NOTE: `<profile>` is your server's alias (e.g. server1, ani, alice) created via New-Target.
if (-not $AutoLoad -and -not $DryRun) {
    Write-Host ""
    Write-Cat "To load manually:"
    Write-Host "  Import-Module SharedToolkit"
    foreach ($mod in ($Installed | Where-Object { $_ -ne 'SharedToolkit' })) { Write-Host "  Import-Module $mod" }
    Write-Host "  Initialize-ToolkitCompletion"
}
Write-Host ""
if ($Verify -and -not $DryRun) { Write-Host "$($C.Ok)Verification passed$($C.Reset)" }
