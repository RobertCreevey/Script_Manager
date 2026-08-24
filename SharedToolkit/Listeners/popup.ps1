# Type: Listener
# Description: Starts a background listener for incoming popup requests (Yes/No) from remote SSH sessions.
param($Config, [array]$Arguments)
$C = if ($global:ToolColors) { $global:ToolColors } else { [PSCustomObject]@{}}
$ArgsOnly = @($Arguments | Where-Object { $_ -notin @("-Force", "-f", "-h", "-?") })
$Action = if ($ArgsOnly[0]) { $ArgsOnly[0] } else { "listen" }  # listen, stop, status
$Port = if ($ArgsOnly[1]) { [int]$ArgsOnly[1] } else { 0 }  # not used, for future TCP listener

switch ($Action) {
    'listen' {
        Write-Host "[popup] Starting background popup listener..." -ForegroundColor Cyan
        # This would run as a background job
        $Script = {
            $ResponseFile = "C:\Users\Public\popup_listener_request.txt"
            $ResponseOut = "C:\Users\Public\popup_listener_response.txt"
            while ($true) {
                if (Test-Path $ResponseFile) {
                    $Request = Get-Content $ResponseFile -Raw | ConvertFrom-Json
                    $wshell = New-Object -ComObject Wscript.Shell
                    $Response = $wshell.Popup($Request.Question, 0, $Request.Title, 4 + 32)
                    @{ Response = $Response; CorrelationId = $Request.CorrelationId } | ConvertTo-Json | Out-File $ResponseOut -Force
                    Remove-Item $ResponseFile -Force
                }
                Start-Sleep -Seconds 1
            }
        }
        $Job = Start-Job -ScriptBlock $Script -Name "PopupListener"
        Write-Host "[popup] Listener started as background job: $($Job.Name) (Id: $($Job.Id))" -ForegroundColor Green
    }
    'stop' {
        Get-Job -Name "PopupListener" -ErrorAction SilentlyContinue | Stop-Job
        Get-Job -Name "PopupListener" -ErrorAction SilentlyContinue | Remove-Job
        Write-Host "[popup] Listener stopped." -ForegroundColor Yellow
    }
    'status' {
        $Job = Get-Job -Name "PopupListener" -ErrorAction SilentlyContinue
        if ($Job) { Write-Host "[popup] Listener running: $($Job.State)" -ForegroundColor Green }
        else { Write-Host "[popup] Listener not running." -ForegroundColor Gray }
    }
    default { Write-Host "$($C.Warn)[ERROR] Usage: popup [listen|stop|status]$($C.Reset)" }
}