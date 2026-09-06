<#
.SYNOPSIS
    Bootstrap script for PlatyPS-based native help generation.

.DESCRIPTION
    This is the starting point for wiring `Get-Help <action>` (MAML) into the
    toolkit, using PlatyPS (Microsoft.PowerShell.PlatyPS).

    Source-of-truth for help content today is `toolkit.json` (canonical name +
    aliases, parameters, switches, builtins, listeners) plus plugin headers
    (`# Type: / # Description:`). This script shows how to derive PlatyPS help
    objects from that data so `Get-Help <Toolkit> <action>` works natively.

    NOTE: Full generation for all 9 toolkits + plugins is staged (see TODOs
    below). This script is safe to run: it imports PlatyPS if available and
    emits the planned help objects without writing files unless -Generate.

.PARAMETER Toolkit
    Toolkit manifest module name, e.g. SSHToolkit. (default: SSHToolkit)

.PARAMETER Generate
    Actually emit/rewrite .md source files in docs/help/<Toolkit>/.

.EXAMPLE
    .\docs\Generate-Help.ps1
    Probe + preview one help object for SSHToolkit::snap.

.EXAMPLE
    .\docs\Generate-Help.ps1 -Toolkit DockerToolkit -Generate
    Write DockerToolkit help markdown sources to docs/help/DockerToolkit/.
#>

# TODO: Run this for every toolkit; commit generated docs/help/<Toolkit>/*.md
#       to source. Then: New-ExternalHelp -Path docs/help/<Toolkit> -OutputPath
#       <ModuleRoot>\en-US\ -Force; bump manifest HelpInfoURI.
# TODO: Also scaffold `about_Toolkit` conceptual help per module.
# TODO: Derive help for user plugins from ~/.toolkit/plugins/* headers.
# TODO: Add a `toolkit help update` action that re-runs this for changed
#       toolkits, so help stays in sync with toolkit.json.

[CmdletBinding()]
param(
    [string]$Toolkit = 'SSHToolkit',
    [switch]$Generate
)

$ModuleRoot = (Get-Item $PSScriptRoot).Parent.FullName   # repo root (...\SharedToolkit_PowerShell_Module)
$Source = Join-Path $ModuleRoot $Toolkit
$Manifest = Join-Path $Source "$Toolkit.psd1"
$ToolkitJson = Join-Path $Source 'toolkit.json'

if (-not (Test-Path $Manifest)) { Write-Error "Toolkit '$Toolkit' not found at $Source"; return }
if (-not (Test-Path $ToolkitJson)) { Write-Error "toolkit.json not found for $Toolkit"; return }

# --- Load PlatyPS --------------------------------------------------------
$HasPlatyPS = $false
try { Import-Module PlatyPS -ErrorAction Stop; $HasPlatyPS = $true } catch { }
if (-not $HasPlatyPS) {
    Write-Host "PlatyPS not available. Install once:" -ForegroundColor Yellow
    Write-Host "  Install-Module -Name PlatyPS -Scope CurrentUser -Force"
}

# --- Load the toolkit manifest data --------------------------------------
$tk = Get-Content $ToolkitJson -Raw | ConvertFrom-Json

# --- Build help objects for a sample action: snap ------------------------
$Action = 'snap'
$aliasList = $tk.actions.$Action          # [canonical, alias1, ...]
$params = $tk.parameters.$Action.PSObject.Properties.Name
$paramAliases = foreach ($p in $params) { $tk.parameters.$Action.$p }

$Synopsis = "$($aliasList[0]) — capture a remote screenshot and pull it locally."
$Description = "Runs the $($aliasList[0]) action: takes a silent screenshot on the target, copies it via SCP, then cleans up. Aliases: $($aliasList -join ', ')."

Write-Host "($Toolkit) Help object preview for action '$Action':" -ForegroundColor Cyan
Write-Host "  Synopsis    : $Synopsis"
Write-Host "  Description : $Description"
Write-Host "  Parameters  : $($params -join ', ')"

if ($HasPlatyPS -and $Generate) {
    $OutDir = Join-Path $ModuleRoot "docs\help\$Toolkit"
    if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Path $OutDir -Force | Out-Null }

    # Conceptual help is written as markdown, then New-ExternalHelp turns it
    # into MAML. Each action becomes a Function help file.
    $md = @()
    $md += "# $($aliasList[0])"
    $md += ""
    $md += "## SYNOPSIS"
    $md += $Synopsis
    $md += "## DESCRIPTION"
    $md += $Description
    if ($params) {
        $md += "## PARAMETERS"
        foreach ($p in $params) {
            $md += "### $p"
            $md += "Alias list: $($($tk.parameters.$Action.$p) -join ', ')"
        }
    }
    $md += "## EXAMPLES"
    $md += '```'
    $md += "<profile> $($aliasList[0]) screenshot.png"
    $md += '```'
    Set-Content (Join-Path $OutDir "$Action.md") ($md -join "`n")
    Write-Host "  Wrote $OutDir\$Action.md" -ForegroundColor Green

    # Generate MAML for THIS toolkit module (en-US) so Get-Help resolves.
    # NOTE: call New-ExternalHelp for each toolkit directory once all .md exist:
    #   New-ExternalHelp -Path "$ModuleRoot\docs\help\$Toolkit" -OutputPath "$Source\en-US\" -Force
}
elseif (-not $HasPlatyPS) {
    Write-Host "  (PlatyPS missing) Would write docs/help/$Toolkit/$Action.md" -ForegroundColor Yellow
}
