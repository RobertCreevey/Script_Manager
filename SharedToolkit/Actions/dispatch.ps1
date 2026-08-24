# Type: Action
# Description: Dispatches an action on any installed toolkit, enabling cross-toolkit automation from any profile context.
param($Config, [array]$Arguments)
$ArgsOnly = @($Arguments | Where-Object { $_ -notin @("-Force", "-f") })
$C = Get-ToolkitColors
if ($ArgsOnly.Count -lt 2) {
    Write-Host "$($C.Warn)[ERROR] Usage: dispatch <toolkit> <action> [args...]$($C.Reset)" -ForegroundColor Red
    Write-Host "$($C.Str)Example: dispatch NetToolkit wol$($C.Reset)"
    return
}
$Toolkit = $ArgsOnly[0]
$Action = $ArgsOnly[1]
$ActionArgs = @()
if ($ArgsOnly.Count -gt 2) { $ActionArgs = $ArgsOnly[2..($ArgsOnly.Count - 1)] }
Write-Host "$($C.Info)[dispatch]$($C.Reset) $($C.Host)$Toolkit$($C.Reset) -> $($C.Action)$Action$($C.Reset) $($ActionArgs -join ' ')"
$null = Invoke-CrossToolkitAction -Toolkit $Toolkit -Action $Action -Arguments $ActionArgs -Config $Config


