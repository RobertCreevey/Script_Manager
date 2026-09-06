# Type: Action
# Description: Speaks the supplied text aloud using the local speech synthesis engine for hands-free audio alerts.
# Aliases: say, tts, voice
param($Config, [array]$Arguments)
$C = Get-ToolkitColors

if (-not $Arguments -or $Arguments.Count -eq 0) {
    Write-Host "$($C.Warn)[speak] No text provided. Usage: speak 'text' [vol <value>]$($C.Reset)"
    Write-Host "$($C.Str)  vol can be: 50%, .5, 0.5, or 1/2$($C.Reset)"
    return
}

$Text = ""
$Volume = 1.0

for ($i = 0; $i -lt $Arguments.Count; $i++) {
    $arg = $Arguments[$i]
    if ($arg -match '^(vol|volume|v)$' -and $i + 1 -lt $Arguments.Count) {
        $volArg = $Arguments[$i + 1]
        if ($volArg -match '(\d+)%') {
            $Volume = [math]::Max(0, [math]::Min(1, [int]$Matches[1] / 100.0))
        }
        elseif ($volArg -match '^(\d+)/(\d+)$') {
            $Volume = [math]::Max(0, [math]::Min(1, [double]$Matches[1] / [double]$Matches[2]))
        }
        elseif ($volArg -match '^\d+$') {
            $Volume = [math]::Max(0, [math]::Min(1, [int]$volArg / 100.0))
        }
        elseif ([double]::TryParse($volArg, [ref]$null)) {
            $Volume = [math]::Max(0, [math]::Min(1, [double]$volArg))
        }
        $i++
    }
    else {
        $Text += $arg + " "
    }
}

$Text = $Text.Trim()
if (-not $Text) {
    $Text = "Notification"
}

try {
    Add-Type -AssemblyName System.Speech -ErrorAction Stop
    $Synth = New-Object System.Speech.Synthesis.SpeechSynthesizer
    $Synth.Volume = [math]::Round($Volume * 100)
    $Synth.Speak($Text)
    $Synth.Dispose()
    
    $volPct = [math]::Round($Volume * 100)
    Write-Host "$($C.Ok)[speak] Spoke: $($C.Action)$Text$($C.Reset) $($C.Str)(vol: $volPct%)$($C.Reset)"
}
catch {
    Write-Host "$($C.Crit)[ERROR] Failed to speak: $_$($C.Reset)"
}
