# Type: Action
# Description: Emits a local system hardware beep tone or custom WAV audio file alert without any GUI interface.
param($Config, [array]$Arguments)

$Frequency = if ($Arguments[0]) { [int]$Arguments[0] } else { 800 }
$DurationMs = if ($Arguments[1]) { [int]$Arguments[1] } else { 400 }
$WavPath = if ($Arguments[2]) { $Arguments[2] } else { $null }

if ($WavPath -and (Test-Path $WavPath)) {
    $Player = New-Object System.Media.SoundPlayer($WavPath)
    $Player.Play()
} else {
    [Console]::Beep($Frequency, $DurationMs)
}