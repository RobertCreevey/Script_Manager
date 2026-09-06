$ErrorActionPreference = 'Stop'

Import-Module .\SharedToolkit\SharedToolkit.psd1 -Force
Import-Module .\SSHToolkit\SSHToolkit.psd1 -Force
Import-Module .\NetToolkit\NetToolkit.psd1 -Force
Import-Module .\DockerToolkit\DockerToolkit.psd1 -Force
Import-Module .\GitToolkit\GitToolkit.psd1 -Force

$name = "smoke_test_$(New-Guid)"
Write-Host "Using profile: $name"

try {
    Register-Target -Name $name -IP 127.0.0.1 -User testuser -Key 'C:\keys\id_rsa'

    Write-Host "`n=== help ==="
    Invoke-Expression "$name help" | Out-Null

    Write-Host "`n=== config view ==="
    Invoke-Expression "$name config view" | Out-Null

    Write-Host "`n=== sys ==="
    Invoke-Expression "$name sys -table" | Out-Null

    Write-Host "`n=== registry ==="
    Invoke-Expression "$name registry" | Out-Null

    Write-Host "`n=== chain list ==="
    Invoke-Expression "$name chain list" | Out-Null

    Write-Host "`n=== help-index toolkits ==="
    Invoke-Expression "$name help-index toolkits" | Out-Null

    Write-Host "`n=== dispatch SharedToolkit toast ==="
    Invoke-Expression "$name dispatch SharedToolkit toast 'Hello from dispatch'" | Out-Null

    Write-Host "`n=== alias resolution ==="
    $resolved = Resolve-ToolkitActionName -Name 'st' -ToolkitPath (Join-Path (Get-Location) 'GitToolkit')
    Write-Host "Resolved 'st' to: $resolved"

    Write-Host "`n=== chain new + run (dry run) ==="
    Invoke-Expression "$name chain new smoketest SharedToolkit::toast 'Smoke test'" | Out-Null
    Invoke-Expression "$name chain run smoketest -DryRun" | Out-Null

    Write-Host "`n=== output formats ==="
    $inputObj = @(@{Id=1; Name="Test"})
    $json = $inputObj | Format-ToolOutput -Format json
    $csv = $inputObj | Format-ToolOutput -Format csv
    Write-Host "JSON: $json"
    Write-Host "CSV: $csv"
    
    Write-Host "`n=== RAW FORMAT TEST ==="
    $raw = $inputObj | Format-ToolOutput -Format raw
    Write-Host "RAW: $raw"

    Write-Host "`n=== profiles list ==="
    Invoke-Expression "$name profiles list" | Out-Null

    Write-Host "`n=== history clear ==="
    Invoke-Expression "$name history clear" | Out-Null

    Write-Host "`n=== logs ==="
    Invoke-Expression "$name logs" | Out-Null

    Write-Host "`n=== health ==="
    Invoke-Expression "$name health" | Out-Null
}
finally {
    Write-Host "`n=== cleanup ==="
    if (Get-Alias $name -ErrorAction SilentlyContinue) {
        Remove-Item Alias:\$name -Force -ErrorAction SilentlyContinue
    }
    $profile = Join-Path (Get-Location) "SSHToolkit\Profiles\$name.json"
    if (Test-Path $profile) { Remove-Item $profile -Force }
    Write-Host "Done"
}
