@{
    RootModule = 'MediaToolkit.psm1'
    ModuleVersion = '1.0.0'
    GUID = 'd4e5f6a7-b8c9-0123-def0-456789012345'
    Author = 'Rober'
    Description = 'Local media and display control'
    PowerShellVersion = '7.0'
    CompatiblePSEditions = @('Core')
    RequiredModules = @('SharedToolkit')
    FunctionsToExport = '*'
    AliasesToExport = '*'
    PrivateData = @{
        PSData = @{
            Tags = @('toolkit', 'media', 'display', 'audio')
            LicenseUri = 'https://github.com/RobertCreevey/Script_Manager/blob/master/LICENSE'
            ProjectUri = 'https://github.com/RobertCreevey/Script_Manager'
            ReleaseNotes = 'Media and display control toolkit'
        }
    }
}

