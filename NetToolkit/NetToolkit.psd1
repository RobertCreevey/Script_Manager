@{
    RootModule = 'NetToolkit.psm1'
    ModuleVersion = '1.0.0'
    GUID = 'c3d4e5f6-a7b8-9012-cdef-345678901234'
    Author = 'Rober'
    Description = 'Network diagnostics and LAN discovery'
    PowerShellVersion = '7.0'
    CompatiblePSEditions = @('Core')
    RequiredModules = @('SharedToolkit')
    FunctionsToExport = '*'
    AliasesToExport = '*'
    PrivateData = @{
        PSData = @{
            Tags = @('toolkit', 'network', 'lan', 'diagnostics')
            LicenseUri = ''
            ProjectUri = 'https://github.com/RobertCreevey/Script_Manager'
            ReleaseNotes = 'Network diagnostics toolkit'
        }
    }
}

