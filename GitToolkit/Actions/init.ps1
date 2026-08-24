# Type: Action
# Description: Initializes a new Git repository.
[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Low')]
param($Config, [array]$Arguments)
$Parsed = Get-ActionArguments -Arguments $Arguments
$ArgsOnly = $Parsed.ArgsOnly
$Format = $Parsed.Format
$Force = $Parsed.Switches.Force
$C = Get-ToolkitColors

$Path = $ArgsOnly[0]
$Bare = $ArgsOnly -contains '--bare'
$Template = $ArgsOnly | Where-Object { $_ -match '^--template=' } | ForEach-Object { $_ -replace '^--template=', '' }
$InitialBranch = $ArgsOnly | Where-Object { $_ -match '^--initial-branch=' } | ForEach-Object { $_ -replace '^--initial-branch=', '' }
$Quiet = $ArgsOnly -contains '-q' -or $ArgsOnly -contains '--quiet'

if ($Path) {
    if (-not (Test-Path $Path)) {
        if (-not $Force -and -not $PSCmdlet.ShouldProcess("File system", "Create directory '$Path'")) { return }
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
    Set-Location $Path
} else {
    Set-Location $Config.Path
}

if (-not $Force -and -not $PSCmdlet.ShouldProcess("Git repository", "Initialize repository")) { return }

$Cmd = "git init"
if ($Bare) { $Cmd += " --bare" }
if ($Template) { $Cmd += " --template=$Template" }
if ($InitialBranch) { $Cmd += " --initial-branch=$InitialBranch" }
if ($Quiet) { $Cmd += " -q" }

& $Cmd

# Set user config from profile
if ($Config.User) { & git config user.name $Config.User }
if ($Config.Email) { & git config user.email $Config.Email }

Write-Host "[OK] Repository initialized" -ForegroundColor Green