<#
.SYNOPSIS
    Bootstrap script for PlatyPS-based native help generation.

.DESCRIPTION
    Generates PlatyPS markdown help sources from each toolkit's toolkit.json.
    By default it previews what would be generated. Use -Generate to write
    docs/help/<Toolkit>/*.md for one or all toolkits.

    Source-of-truth for help content is toolkit.json (canonical name + aliases,
    parameters, switches, builtins, listeners) plus plugin headers
    (`# Type: / # Description:`). This script derives PlatyPS help objects from
    that data so `Get-Help <Toolkit> <action>` can work natively after MAML
    compilation with New-ExternalHelp.

.PARAMETER Toolkit
    Toolkit manifest module name, e.g. SSHToolkit. (default: SSHToolkit)

.PARAMETER Generate
    Actually emit/rewrite .md source files in docs/help/<Toolkit>/.

.PARAMETER All
    Generate help for all installed toolkits. Implies -Generate.

.EXAMPLE
    .\docs\Generate-Help.ps1
    Preview help objects for all actions in SSHToolkit.

.EXAMPLE
    .\docs\Generate-Help.ps1 -Toolkit DockerToolkit -Generate
    Write DockerToolkit help markdown sources to docs/help/DockerToolkit/.

.EXAMPLE
    .\docs\Generate-Help.ps1 -All -Generate
    Write help markdown sources for every installed toolkit.
#>

[CmdletBinding()]
param(
    [string]$Toolkit = 'SSHToolkit',
    [switch]$Generate,
    [switch]$All
)

$ModuleRoot = (Get-Item $PSScriptRoot).Parent.FullName   # repo root (...\SharedToolkit_PowerShell_Module)

# --- Load PlatyPS --------------------------------------------------------
$HasPlatyPS = $false
try { Import-Module PlatyPS -ErrorAction Stop; $HasPlatyPS = $true } catch { }
if (-not $HasPlatyPS) {
    Write-Host "PlatyPS not available. Install once:" -ForegroundColor Yellow
    Write-Host "  Install-Module -Name PlatyPS -Scope CurrentUser -Force"
}

# --- Discover toolkits ---------------------------------------------------
$AllToolkits = Get-ChildItem $ModuleRoot -Directory | Where-Object { $_.Name -like '*Toolkit' } | Select-Object -ExpandProperty Name
if ($All) {
    $Toolkits = $AllToolkits
} else {
    if ($AllToolkits -notcontains $Toolkit) { Write-Error "Toolkit '$Toolkit' not found at $ModuleRoot"; return }
    $Toolkits = @($Toolkit)
}

# --- Helpers -------------------------------------------------------------
function New-ActionHelpMarkdown {
    param(
        [string]$Toolkit,
        [string]$Action,
        [array]$AliasList,
        [hashtable]$Parameters,
        $ToolkitData
    )
    $Canonical = $AliasList[0]
    $Aliases = ($AliasList | Where-Object { $_ -ne $Canonical }) -join ', '

    $md = @()
    $md += "# $Canonical"
    $md += ""
    $md += "## SYNOPSIS"
    $md += "$Canonical — $($ToolkitData.description) (action: $Action)"
    $md += ""
    $md += "## DESCRIPTION"
    if ($Aliases) {
        $md += "Canonical action: $Canonical. Aliases: $Aliases."
    } else {
        $md += "Canonical action: $Canonical."
    }
    $md += ""
    $md += "## SYNTAX"
    $md += '```'
    $md += "profile $Canonical [args...]"
    if ($Aliases) { $md += "profile $($Aliases.Split(',')[0].Trim()) [args...]" }
    $md += '```'
    $md += ""

    if ($Parameters.Count -gt 0) {
        $md += "## PARAMETERS"
        foreach ($p in $Parameters.Keys) {
            $md += "### $p"
            $pAliases = @($Parameters[$p]) -ne $p
            if ($pAliases) { $md += "Aliases: $($pAliases -join ', ')" }
            $md += ""
        }
    }

    $md += "## EXAMPLES"
    $md += '```'
    $md += "profile $Canonical"
    $md += '```'
    return ($md -join "`n")
}

# --- Generate ------------------------------------------------------------
foreach ($tk in $Toolkits) {
    $Source = Join-Path $ModuleRoot $tk
    $ToolkitJson = Join-Path $Source 'toolkit.json'
    if (-not (Test-Path $ToolkitJson)) { Write-Warning "$tk : toolkit.json missing"; continue }

    $tkData = Get-Content $ToolkitJson -Raw | ConvertFrom-Json

    $Actions = @{}
    if ($tkData.actions) {
        $tkData.actions.PSObject.Properties | ForEach-Object {
            $Actions[$_.Name] = @($_.Value)
        }
    }
    if ($tkData.builtins) {
        $tkData.builtins.PSObject.Properties | ForEach-Object {
            $Actions[$_.Name] = @($_.Value)
        }
    }

    if ($Actions.Count -eq 0) { Write-Host "$tk : no actions"; continue }

    Write-Host "`n($tk) Generating help for $($Actions.Count) actions..." -ForegroundColor Cyan

    if ($Generate) {
        $OutDir = Join-Path $ModuleRoot "docs\help\$tk"
        if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Path $OutDir -Force | Out-Null }
    }

    foreach ($Action in $Actions.Keys | Sort-Object) {
        $AliasList = $Actions[$Action]
        $paramNames = @()
        if ($tkData.parameters -and $tkData.parameters.$Action) {
            $paramNames = @($tkData.parameters.$Action.PSObject.Properties.Name)
        }
        $paramMap = @{}
        foreach ($p in $paramNames) {
            $paramMap[$p] = @($tkData.parameters.$Action.$p)
        }

        $md = New-ActionHelpMarkdown -Toolkit $tk -Action $Action -AliasList $AliasList -Parameters $paramMap -ToolkitData $tkData

        if ($Generate) {
            $OutFile = Join-Path $OutDir "$Action.md"
            Set-Content -Path $OutFile -Value $md -Encoding utf8
            Write-Host "  [OK] $OutFile" -ForegroundColor Green
        } else {
            Write-Host "  [$Action] $($AliasList[0])" -ForegroundColor Gray
            Write-Host "    Aliases : $($AliasList -join ', ')" -ForegroundColor DarkGray
            if ($paramNames) { Write-Host "    Params  : $($paramNames -join ', ')" -ForegroundColor DarkGray }
        }
    }

    if ($Generate -and $HasPlatyPS) {
        $MamlDir = Join-Path $Source 'en-US'
        if (-not (Test-Path $MamlDir)) { New-Item -ItemType Directory -Path $MamlDir -Force | Out-Null }
        Write-Host "`n  To compile MAML for $tk :" -ForegroundColor Yellow
        Write-Host "    New-ExternalHelp -Path `"$OutDir`" -OutputPath `"$MamlDir`" -Force" -ForegroundColor Yellow
    }
}
