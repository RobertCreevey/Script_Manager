# Type: Action
# Description: Displays the permanent banner/legend with static help, key shortcuts, and quick-start reminders.
param($Config, [array]$Arguments)
$C = Get-ToolkitColors
$ctx = if ($global:ToolContext) { $global:ToolContext } else { "local" }
$time = Get-Date -Format "HH:mm:ss"
$stats = Get-ToolkitSystemStats

Write-Host ""
Write-Host "$($C.Sys)╔══════════════════════════════════════════════════════════════════════════════╗$($C.Reset)"
Write-Host "$($C.Sys)║$($C.Reset)  $($C.Action)Script_Manager$($C.Reset) — Permanent Banner & Legend                                   $($C.Sys)║$($C.Reset)"
Write-Host "$($C.Sys)╠══════════════════════════════════════════════════════════════════════════════╣$($C.Reset)"
Write-Host "$($C.Sys)║$($C.Reset)  $($C.Info)Context:    $($C.Host)<profile>$($C.Reset) — target alias (e.g. server1, work, aws-prod)              $($C.Sys)║$($C.Reset)"
Write-Host "$($C.Sys)║$($C.Reset)  $($C.Info)Action:     $($C.Action)<profile> <action> [args...]$($C.Reset) — run any action                       $($C.Sys)║$($C.Reset)"
Write-Host "$($C.Sys)║$($C.Reset)  $($C.Info)Say:        $($C.Action)<profile> say <text>$($C.Reset) — speak or print text (alias: speak/tts) $($C.Sys)║$($C.Reset)"
Write-Host "$($C.Sys)║$($C.Reset)  $($C.Info)Help:       $($C.Action)<profile> help$($C.Reset) — full action index                           $($C.Sys)║$($C.Reset)"
Write-Host "$($C.Sys)║$($C.Reset)  $($C.Info)Help-index: $($C.Action)<profile> help-index actions$($C.Reset) — every action across toolkits    $($C.Sys)║$($C.Reset)"
Write-Host "$($C.Sys)║$($C.Reset)  $($C.Info)Banner:     $($C.Action)banner$($C.Reset) — show this legend anytime                              $($C.Sys)║$($C.Reset)"
Write-Host "$($C.Sys)║$($C.Reset)  $($C.Info)Theme:      $($C.Action)theme$($C.Reset) — switch color theme (default / light / mono)           $($C.Sys)║$($C.Reset)"
Write-Host "$($C.Sys)║$($C.Reset)  $($C.Info)Dispatch:   $($C.Action)<profile> dispatch <Toolkit> <action>$($C.Reset) — cross-toolkit call   $($C.Sys)║$($C.Reset)"
Write-Host "$($C.Sys)║$($C.Reset)  $($C.Info)Chains:     $($C.Action)<profile> chain new|run|list <name>$($C.Reset) — compose workflows    $($C.Sys)║$($C.Reset)"
Write-Host "$($C.Sys)║$($C.Reset)  $($C.Info)Events:     $($C.Action)events$($C.Reset) — view recent event log                              $($C.Sys)║$($C.Reset)"
Write-Host "$($C.Sys)║$($C.Reset)  $($C.Info)Plugin:     $($C.Action)plugin new|load|list|run <name>$($C.Reset) — lightweight extensions       $($C.Sys)║$($C.Reset)"
Write-Host "$($C.Sys)║$($C.Reset)  $($C.Info)Output:     $($C.Action)-json$($C.Reset) $($C.Action)-csv$($C.Reset) $($C.Action)-raw$($C.Reset) $($C.Action)-table$($C.Reset) — structured output on every action  $($C.Sys)║$($C.Reset)"
Write-Host "$($C.Sys)║$($C.Reset)  $($C.Info)Tab:        Complete actions, chains, and switches automatically             $($C.Sys)║$($C.Reset)"
Write-Host "$($C.Sys)╠══════════════════════════════════════════════════════════════════════════════╣$($C.Reset)"
Write-Host "$($C.Sys)║$($C.Reset)  $($C.Sys)Active:$($C.Reset) $ctx  |  $($C.Sys)Time:$($C.Reset) $time  |  $($C.Sys)CPU:$($C.Reset) $($stats.CPU)%  |  $($C.Sys)RAM:$($C.Reset) $($stats.RAMFree)/$($stats.RAMTotal) GB$(' ' * 12)$($C.Sys)║$($C.Reset)"
Write-Host "$($C.Sys)╚══════════════════════════════════════════════════════════════════════════════╝$($C.Reset)"
Write-Host ""
if ($Arguments) {
    Write-Host "$($C.Str)$($Arguments -join ' ')$($C.Reset)"
}
