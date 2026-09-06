$script:RepoRoot = Split-Path -Parent $PSScriptRoot
$script:SharedManifest = Join-Path $script:RepoRoot 'SharedToolkit\SharedToolkit.psd1'
Write-Host "TOP: SharedManifest=$script:SharedManifest"

Import-Module Pester

Describe "Scope test" {
    BeforeAll {
        Write-Host "BeforeAll: SharedManifest=$script:SharedManifest"
        Write-Host "BeforeAll: RepoRoot=$script:RepoRoot"
    }
    It "checks scope" {
        Write-Host "It: SharedManifest=$script:SharedManifest"
        $true | Should -Be $true
    }
}
