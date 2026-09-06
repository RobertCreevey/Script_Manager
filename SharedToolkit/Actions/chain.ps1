# Type: Action
# Description: Lists, creates, or runs named chains of steps; each step is an action executed in the current profile context.
param($Config, [array]$Arguments)
$ChainDirs = Get-ToolkitChainDirs
$Sub = if ($Arguments[0]) { $Arguments[0] } else { "list" }
$Name = if ($Arguments[1]) { $Arguments[1] } else { $null }
$C = Get-ToolkitColors

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
            $First = $Parts[0]
            $Toolkit = $null
            $Action = $First
            $ArgStart = 1
            if ($First -match '^([A-Za-z0-9_]+)::(.+)$') {
                $Toolkit = $Matches[1]
                $Action = $Matches[2]
            } elseif ($First -match '^([A-Za-z0-9_]+):(.+)$') {
                $Toolkit = $Matches[1]
                $Action = $Matches[2]
            }
            [PSCustomObject]@{ Toolkit = $Toolkit; Action = $Action; Args = @($Parts | Select-Object -Skip $ArgStart) }
        }
    }
    [PSCustomObject]@{ Steps = $Steps } | ConvertTo-Json -Depth 5 | Out-File "$global:SharedToolkitPath\Chains\$Name.json" -Force
    Write-Host "[OK] Chain '$Name' created with $($Steps.Count) steps." -ForegroundColor Green
    Write-ToolkitEvent -Name "ChainCreated" -Data $Name -Config $Config
    return
}

if ($Sub -eq "run") {
    if (-not $Name) { Write-Host "[ERROR] Usage: chain run <name> [-Force] [-DryRun]" -ForegroundColor Red ; return }
    $File = $null
    foreach ($d in $ChainDirs) { if (Test-Path "$d\$Name.json") { $File = "$d\$Name.json"; break } }
    if (-not $File) { Write-Host "[ERROR] Chain '$Name' not found." -ForegroundColor Red ; return }
    $Chain = Get-Content $File | ConvertFrom-Json

    $CtxStr = if ($Config) { "$($Config.User)@$($Config.IP)" } else { "local" }
    $HasMutation = $Chain.Steps | Where-Object { $_.Action -in @("run", "service", "process", "shutdown", "push", "pull", "lock", "msg", "wol", "snap", "restart") }
    $HasCrossToolkit = $Chain.Steps | Where-Object { $_.Toolkit }

    $Force = $false
    $DryRun = $false
    $ConfirmAnswer = $null
    if ($Arguments.Count -gt 2) {
        $Extra = $Arguments[2..($Arguments.Count - 1)]
        $Force = ($Extra -contains "-Force") -or ($Extra -contains "-f")
        $DryRun = ($Extra -contains "-DryRun")
        $AnsIdx = $Extra.IndexOf("-ConfirmAnswer")
        if ($AnsIdx -ge 0 -and $AnsIdx + 1 -lt $Extra.Count) { $ConfirmAnswer = $Extra[$AnsIdx + 1] }
    }

    Write-Host ""
    Write-Host "$($C.Sys)CHAIN: $($C.Action)$Name$($C.Reset)  ($($Chain.Steps.Count) steps)" -ForegroundColor White
    if ($HasCrossToolkit) { Write-Host "$($C.Info)  (cross-toolkit composition)" -ForegroundColor Cyan }
    Write-Host (Format-ChainPreview $File)
    Write-Host ""

    if ($DryRun) {
        Write-Host "$($C.Warn)DRY RUN — no steps executed.$($C.Reset)" -ForegroundColor Yellow
        Write-Host ""
        return
    }

    if (-not $Force) {
        $Confirmed = Confirm-ToolkitAction -Problem "About to execute chain '$Name'" -WillDo ("Steps:`n" + (Format-ChainPreview $File)) -Target $CtxStr -Dangerous:($HasMutation -ne $null) -Answer $ConfirmAnswer
        if (-not $Confirmed) { Write-ToolkitEvent -Name "ChainAborted" -Data $Name -Config $Config ; return }
    }

    Write-Host "[chain] Running '$Name' ($($Chain.Steps.Count) steps) in context $($C.Host)$CtxStr$($C.Reset)..." -ForegroundColor Magenta
    foreach ($Step in $Chain.Steps) {
        $ToolkitLabel = if ($Step.Toolkit) { "$($Step.Toolkit)::" } else { "" }
        Write-Host "$($C.Param)--> $($C.Action)$ToolkitLabel$($Step.Action)$($C.Reset) $($Step.Args -join ' ')"
        try {
            if ($Step.Toolkit) {
                $null = Invoke-CrossToolkitAction -Toolkit $Step.Toolkit -Action $Step.Action -Arguments $Step.Args -Config $Config
            } else {
                Invoke-UniversalToolkitRouter -Action $Step.Action -ForwardedArgs $Step.Args
            }
        } catch {
            Write-ToolkitError -Message "Chain step '$ToolkitLabel$($Step.Action)' failed: $_" -Severity Error -Config $Config
        }
    }
    Write-Host "[chain] '$Name' complete." -ForegroundColor Green
    Write-ToolkitEvent -Name "ChainRun" -Data $Name -Config $Config
    return
}

Write-Host "[ERROR] Usage: chain [list|new|run] <name> ..." -ForegroundColor Red
