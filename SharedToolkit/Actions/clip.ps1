# Type: Action
# Description: Reads the clipboard to the console, or sets it to the supplied text when arguments are given.
param($Config, [array]$Arguments)
if ($Arguments) {
    $Text = $Arguments -join " "
    Set-Clipboard -Value $Text
    Write-Host "[clip] Set clipboard to: $Text" -ForegroundColor Cyan
} else {
    $Data = Get-Clipboard -Raw
    Write-Host $Data
}
