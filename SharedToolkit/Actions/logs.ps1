# Type: Action
# Description: View and tail toolkit logs with filtering support.
param($Config, [array]$Arguments)

$C = Get-ToolkitColors
$LogPath = "$env:USERPROFILE\Documents\SSHToolkit_CommandHistory.log"
$EventPath = "$env:USERPROFILE\Documents\SSHToolkit_Events.log"
$Follow = $false
$Filter = ""
$Lines = 50
$Toolkit = ""

for ($i = 0; $i -lt $Arguments.Count; $i++) {
    switch ($Arguments[$i]) {
        '-f' { $Follow = $true }
        '-filter' { if ($i+1 -lt $Arguments.Count) { $Filter = $Arguments[++$i] } }
        '-lines' { if ($i+1 -lt $Arguments.Count) { $Lines = [int]$Arguments[++$i] } }
        '-toolkit' { if ($i+1 -lt $Arguments.Count) { $Toolkit = $Arguments[++$i] } }
        '-h' {
            Write-Host "$($C.Info)Usage: logs [-f] [-filter <text>] [-lines <n>] [-toolkit <name>]$($C.Reset)"
            Write-Host "$($C.Str)  -f         Follow (tail -f) mode$($C.Reset)"
            Write-Host "$($C.Str)  -filter    Filter by text (regex)$($C.Reset)"
            Write-Host "$($C.Str)  -lines     Number of lines to show (default 50)$($C.Reset)"
            Write-Host "$($C.Str)  -toolkit   Filter by toolkit name$($C.Reset)"
            return
        }
    }
}

if ($Follow) {
    Write-Host "$($C.Info)[logs] Following $LogPath (Ctrl+C to stop)...$($C.Reset)"
    try {
        Get-Content $LogPath -Wait -Tail $Lines -ErrorAction Stop | ForEach-Object {
            if ($Filter -and $_ -notmatch $Filter) { return }
            if ($Toolkit -and $_ -notmatch "\[$Toolkit\]") { return }
            $_
        }
    } catch {
        Write-Host "$($C.Crit)Error: $_$($C.Reset)"
    }
    return
}

$Files = @($LogPath, $EventPath)
foreach ($File in $Files) {
    if (Test-Path $File) {
        $Content = Get-Content $File -Tail $Lines -ErrorAction SilentlyContinue
        if ($Filter) {
            $Content = $Content | Where-Object { $_ -match $Filter }
        }
        if ($Toolkit) {
            $Content = $Content | Where-Object { $_ -match "\[$Toolkit\]" }
        }
        if ($Content) {
            Write-Host "$($C.Host)=== $([IO.Path]::GetFileName($File)) ===$($C.Reset)"
            $Content
            Write-Host ""
        }
    }
}
