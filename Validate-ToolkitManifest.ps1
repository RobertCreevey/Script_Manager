<#
.SYNOPSIS
    Validates all toolkit.json manifests.
.DESCRIPTION
    Validates each toolkit's manifest for required fields, structure, and consistency.
.PARAMETER ToolkitsPath
    Root directory containing toolkit folders (default: user modules directory)
#>
[CmdletBinding()]
param(
    [string]$ToolkitsPath = "$env:USERPROFILE\Documents\PowerShell\Modules"
)

$ErrorActionPreference = "Stop"

function Write-Step { param([string]$Message) Write-Host "`n[VALIDATE] $Message" -ForegroundColor Cyan }
function Write-OK   { param([string]$Message) Write-Host "  [OK] $Message" -ForegroundColor Green }
function Write-Warn { param([string]$Message) Write-Host "  [WARN] $Message" -ForegroundColor Yellow }
function Write-Err  { param([string]$Message) Write-Host "  [ERR] $Message" -ForegroundColor Red }

# Find toolkit folders
$ToolkitDirs = Get-ChildItem $ToolkitsPath -Directory | Where-Object {
    Test-Path "$($_.FullName)\$($_.Name).psm1"
} | Sort-Object Name

$Results = @()
$TotalErrors = 0
$TotalWarnings = 0

foreach ($Dir in $ToolkitDirs) {
    $ManifestPath = "$($Dir.FullName)\toolkit.json"
    $ToolkitName = $Dir.Name
    
    Write-Step "Validating $ToolkitName..."
    
    if (-not (Test-Path $ManifestPath)) {
        Write-Err "No manifest found at $ManifestPath"
        $Results += @{Toolkit=$ToolkitName; Errors=1; Warnings=0; Message="Missing manifest"}
        $TotalErrors++
        continue
    }
    
    $ManifestJson = Get-Content $ManifestPath -Raw
    $Manifest = $null
    $ParseErrors = 0
    
    try {
        $Manifest = $ManifestJson | ConvertFrom-Json -ErrorAction Stop
    } catch {
        Write-Err "JSON parse error: $($_.Exception.Message)"
        $ParseErrors++
        $TotalErrors++
    }
    
    if ($ParseErrors -gt 0) {
        $Results += @{Toolkit=$ToolkitName; Errors=$ParseErrors; Warnings=0; Message="Parse error"}
        continue
    }
    
    # Custom validations
    $CustomErrors = 0
    $CustomWarnings = 0
    
    # Required fields
    $RequiredFields = @('version', 'description', 'actions')
    foreach ($Field in $RequiredFields) {
        if (-not $Manifest.$Field) {
            Write-Err "Missing required field: $Field"
            $CustomErrors++
        }
    }
    
    # Version format
    if ($Manifest.version -and $Manifest.version -notmatch '^\d+\.\d+\.\d+(-[a-zA-Z0-9]+)?$') {
        Write-Err "Invalid version format: $($Manifest.version) (expected semver)"
        $CustomErrors++
    }
    
    # Description length
    if ($Manifest.description -and $Manifest.description.Length -lt 10) {
        Write-Warn "Description is very short (< 10 chars)"
        $CustomWarnings++
    }
    
    # Actions validation
    if ($Manifest.actions) {
        foreach ($Action in $Manifest.actions.PSObject.Properties) {
            $Aliases = $Action.Value
            if (-not $Aliases -or $Aliases.Count -eq 0) {
                Write-Err "Action '$($Action.Name)' has empty alias list"
                $CustomErrors++
            } elseif ($Aliases[0] -ne $Action.Name) {
                Write-Warn "Action '$($Action.Name)' canonical name doesn't match first alias '$($Aliases[0])'"
                $CustomWarnings++
            }
            # Check for duplicates
            $Duplicates = $Aliases | Group-Object | Where-Object { $_.Count -gt 1 }
            if ($Duplicates) {
                Write-Warn "Action '$($Action.Name)' has duplicate aliases: $($Duplicates.Name -join ', ')"
                $CustomWarnings++
            }
        }
    } else {
        Write-Err "Actions property missing or empty"
        $CustomErrors++
    }
    
    # Parameters validation
    if ($Manifest.parameters) {
        foreach ($ParamAction in $Manifest.parameters.PSObject.Properties) {
            if (-not $Manifest.actions[$ParamAction.Name]) {
                Write-Warn "Parameters defined for unknown action '$($ParamAction.Name)'"
                $CustomWarnings++
            } else {
                foreach ($Param in $ParamAction.Value.PSObject.Properties) {
                    $Aliases = $Param.Value
                    if ($Aliases.Count -eq 0) {
                        Write-Warn "Parameter '$($ParamAction.Name).$($Param.Name)' has empty alias list"
                        $CustomWarnings++
                    }
                    if ($Aliases[0] -ne $Param.Name) {
                        Write-Warn "Parameter '$($ParamAction.Name).$($Param.Name)' canonical doesn't match first alias '$($Aliases[0])'"
                        $CustomWarnings++
                    }
                }
            }
        }
    }
    
    # Switches validation
    if (-not $Manifest.switches) {
        Write-Err "Missing switches definition"
        $CustomErrors++
    } elseif (-not $Manifest.switches.Global) {
        Write-Warn "Missing switches.Global definition"
        $CustomWarnings++
    }
    
    # Listeners validation
    if ($Manifest.listeners) {
        foreach ($Listener in $Manifest.listeners.PSObject.Properties) {
            $Aliases = $Listener.Value
            if ($Aliases.Count -eq 0) {
                Write-Warn "Listener '$($Listener.Name)' has empty alias list"
                $CustomWarnings++
            }
        }
    }
    
    # Builtins validation
    if (-not $Manifest.builtins) {
        Write-Err "Missing builtins definition"
        $CustomErrors++
    } else {
        $RequiredBuiltins = @('help', 'config', 'online')
        foreach ($Req in $RequiredBuiltins) {
            if (-not $Manifest.builtins[$Req]) {
                Write-Warn "Missing required builtin '$Req'"
                $CustomWarnings++
            }
        }
    }
    
    $TotalErrors += $CustomErrors + $ParseErrors
    $TotalWarnings += $CustomWarnings
    
    $Results += @{
        Toolkit = $ToolkitName
        Errors = $ParseErrors + $CustomErrors
        Warnings = $CustomWarnings
    }
    
    if ($ParseErrors + $CustomErrors -eq 0) {
        Write-OK "$ToolkitName valid"
    }
}

# Summary
Write-Step "Validation Summary"
$TotalToolkits = $Results.Count
$ValidToolkits = ($Results | Where-Object { $_.Errors -eq 0 }).Count
Write-Host "Toolkits: $TotalToolkits | Valid: $ValidToolkits | Errors: $TotalErrors | Warnings: $TotalWarnings"

if ($TotalErrors -gt 0) {
    Write-Err "$TotalErrors error(s) found"
    exit 1
} else {
    Write-OK "All toolkits valid"
}