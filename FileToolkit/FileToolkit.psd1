@{
    RootModule = 'FileToolkit.psm1'
    ModuleVersion = '1.0.0'
    GUID = 'e5f6a7b8-c9d0-1234-ef01-567890123456'
    Author = 'Rober'
    Description = 'File operations and search'
    PowerShellVersion = '7.0'
    CompatiblePSEditions = @('Core')
    RequiredModules = @('SharedToolkit')
    FunctionsToExport = '*'
    AliasesToExport = '*'
    PrivateData = @{
        PSData = @{
            Tags = @('toolkit', 'file', 'search', 'filesystem')
            LicenseUri = ''
            ProjectUri = ''
            ReleaseNotes = 'File operations toolkit'
        }
    }
}

