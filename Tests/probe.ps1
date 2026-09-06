$RepoRoot = Split-Path -Parent $PSScriptRoot
$SharedManifest = Join-Path $RepoRoot 'SharedToolkit\SharedToolkit.psd1'
Write-Host "SharedManifest path: $SharedManifest"
Write-Host "Exists: $(Test-Path $SharedManifest)"

Import-Module $SharedManifest -Force -ErrorAction Stop
Write-Host "Module loaded OK"

Describe "Quick probe" {
    BeforeAll {
        Write-Host "BeforeAll running"
        Write-Host "SharedManifest in BeforeAll: $SharedManifest"
    }
    It "can get colors" {
        $C = Get-ToolkitColors
        $C | Should -Not -BeNullOrEmpty
    }
}
