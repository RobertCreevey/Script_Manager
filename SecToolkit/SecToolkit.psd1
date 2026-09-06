@{
    RootModule = 'SecToolkit.psm1'
    ModuleVersion = '1.0.0'
    GUID = 'f6a7b8c9-d0e1-2345-f012-678901234567'
    Author = 'Rober'
    Description = 'Local security auditing'
    PowerShellVersion = '7.0'
    CompatiblePSEditions = @('Core')
    RequiredModules = @('SharedToolkit')
    FunctionsToExport = '*'
    AliasesToExport = '*'
    PrivateData = @{
        PSData = @{
            Tags = @('toolkit', 'security', 'audit', 'hardening')
            LicenseUri = ''
            ProjectUri = ''
            ReleaseNotes = 'Security auditing toolkit'
        }
    }
}

