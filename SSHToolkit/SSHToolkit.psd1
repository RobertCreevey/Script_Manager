@{
    RootModule = 'SSHToolkit.psm1'
    ModuleVersion = '1.0.0'
    GUID = 'b2c3d4e5-f6a7-8901-bcde-f23456789012'
    Author = 'Rober'
    Description = 'LAN SSH administration - profiles, remote actions, file transfer, visual interaction'
    PowerShellVersion = '7.0'
    CompatiblePSEditions = @('Core')
    RequiredModules = @('SharedToolkit')
    FunctionsToExport = @(
        'Register-Target'
        'Invoke-UniversalToolkitRouter'
    )
    AliasesToExport = @(
        'ani'
        'alice'
        'newtarget'
    )
    PrivateData = @{
        PSData = @{
            Tags = @('toolkit', 'ssh', 'remote', 'lan', 'administration')
            LicenseUri = ''
            ProjectUri = ''
            ReleaseNotes = 'SSH LAN administration toolkit'
        }
    }
}