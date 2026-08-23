# Type: Action
# Description: Speaks the supplied text aloud using the local speech synthesis engine for hands-free audio alerts.
param($Config, [array]$Arguments)
$Text = if ($Arguments) { $Arguments -join " " } else { "Notification" }
Add-Type -AssemblyName System.speech
$Synth = New-Object System.Speech.Synthesis.SpeechSynthesizer
$Synth.Speak($Text)
$Synth.Dispose()
