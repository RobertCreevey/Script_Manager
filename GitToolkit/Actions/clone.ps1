# Type: Action
# Description: Clones a Git repository.
[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Low')]
param($Config, [array]$Arguments)
$Parsed = Get-ActionArguments -Arguments $Arguments
$ArgsOnly = $Parsed.ArgsOnly
$Format = $Parsed.Format
$Force = $Parsed.Switches.Force
$C = Get-ToolkitColors

$Url = $ArgsOnly[0]
$Path = $ArgsOnly[1]
$Branch = $ArgsOnly | Where-Object { $_ -match '^-b=' -or $_ -match '^--branch=' } | ForEach-Object { $_ -replace '^-b=', '' -replace '^--branch=', '' }
$Depth = $ArgsOnly | Where-Object { $_ -match '^--depth=' } | ForEach-Object { $_ -replace '^--depth=', '' }
$Recursive = $ArgsOnly -contains '--recursive'
$RecurseSubmodules = $ArgsOnly -contains '--recurse-submodules'
$SingleBranch = $ArgsOnly -contains '--single-branch'
$Bare = $ArgsOnly -contains '--bare'
$NoCheckout = $ArgsOnly -contains '--no-checkout'

if (-not $Url) {
    Write-Host "$($C.Warn)[ERROR] Usage: clone <url> [path] [-b branch] [--depth N] [--recursive] [--bare]$($C.Reset)"
    return
}

if (-not $Path) {
    $Path = (Split-Path $Url -Leaf) -replace '\.git$', ''
}

if (-not $Force -and -not $PSCmdlet.ShouldProcess("File system", "Clone repository to '$Path'")) { return }

$Cmd = "git clone"
if ($Branch) { $Cmd += " -b $Branch" }
if ($Depth) { $Cmd += " --depth=$Depth" }
if ($Recursive) { $Cmd += " --recursive" }
if ($RecurseSubmodules) { $Cmd += " --recurse-submodules" }
if ($SingleBranch) { $Cmd += " --single-branch" }
if ($Bare) { $Cmd += " --bare" }
if ($NoCheckout) { $Cmd += " --no-checkout" }
$Cmd += " $Url $Path"

& $Cmd

if ($LASTEXITCODE -eq 0 -and -not $Bare -and -not $NoCheckout) {
    Set-Location $Path
    if ($Config.User) { & git config user.name $Config.User }
    if ($Config.Email) { & git config user.email $Config.Email }
    Write-Host "[OK] Repository cloned to $Path" -ForegroundColor Green
}