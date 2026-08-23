# Type: Action
# Description: Lists, creates, or runs named chains of steps; each step is an action executed in the current profile context.
param($Config, [array]$Arguments)
$ChainDirs = @("$global:SSHToolkitPath\Chains", "$global:SharedToolkitPath\Chains")
$Sub = if ($Arguments[0]) { $Arguments[0] } else { "list" }
$Name = if ($Arguments[1]) { $Arguments[1] } else { $null }
$C = if ($global:ToolColors) { $global:ToolColors } else { [PSCustomObject]@{} }

if ($Sub -eq "list") {
    $Found = $false
    foreach ($d in $ChainDirs) {
        if (Test-Path $d) {
            Get-ChildItem $d -Filter *.json -ErrorAction SilentlyContinue | ForEach-Object {
                $Ch = Get-Content $_.FullName | ConvertFrom-Json
                Write-Host "$($_.BaseName) ($($Ch.Steps.Count) steps)$(if($d -match 'Shared'){' [shared]'}else{' [ssh]'})" -ForegroundColor Cyan
                $Found = $true
            }
        }
    }
    if (-not $Found) { Write-Host "(no chains defined)" -ForegroundColor Gray }
    return
}

if ($Sub -eq "new") {
    if (-not $Name) { Write-Host "[ERROR] Usage: chain new <name> <step>; <step>; ..." -ForegroundColor Red ; return }
    $Raw = if ($Arguments[2]) { ($Arguments[2..($Arguments.Length - 1)] -join " ") } else { "" }
    $Steps = $Raw -split ';' | ForEach-Object {
        $s = $_.Trim()
        if ($s) {
            $Parts = $s -split ' '
            [PSCustomObject]@{ Action = $Parts[0]; Args = @($Parts | Select-Object -Skip 1) }
        }
    }
    [PSCustomObject]@{ Steps = $Steps } | ConvertTo-Json -Depth 5 | Out-File "$global:SharedToolkitPath\Chains\$Name.json" -Force
    Write-Host "[OK] Chain '$Name' created with $($Steps.Count) steps." -ForegroundColor Green
    Invoke-ToolEvent -Name "ChainCreated" -Data $Name -Config $Config
    return
}

if ($Sub -eq "run") {
    if (-not $Name) { Write-Host "[ERROR] Usage: chain run <name>" -ForegroundColor Red ; return }
    $File = $null
    foreach ($d in $ChainDirs) { if (Test-Path "$d\$Name.json") { $File = "$d\$Name.json"; break } }
    if (-not $File) { Write-Host "[ERROR] Chain '$Name' not found." -ForegroundColor Red ; return }
    $Chain = Get-Content $File | ConvertFrom-Json
    Write-Host "[chain] Running '$Name' ($($Chain.Steps.Count) steps) in context $($C.Host)$(if($Config){$Config.User+'@'+$Config.IP}else{'local'})$($C.Reset)..." -ForegroundColor Magenta
    foreach ($Step in $Chain.Steps) {
        Write-Host "$($C.Param)--> $($C.Action)$($Step.Action)$($C.Reset) $($Step.Args -join ' ')"
        try { Invoke-UniversalToolkitRouter -Action $Step.Action -ForwardedArgs $Step.Args } catch {
            Invoke-ToolError -Message "Chain step '$($Step.Action)' failed: $_" -Severity Error -Config $Config
        }
    }
    Write-Host "[chain] '$Name' complete." -ForegroundColor Green
    Invoke-ToolEvent -Name "ChainRun" -Data $Name -Config $Config
    return
}

Write-Host "[ERROR] Usage: chain [list|new|run] <name> ..." -ForegroundColor Red
