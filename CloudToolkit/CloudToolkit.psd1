@{
    RootModule = 'CloudToolkit.psm1'
    ModuleVersion = '1.0.0'
    GUID = 'a7b8c9d0-e1f2-3456-0123-789012345678'
    Author = 'Rober'
    Description = 'Multi-cloud management (AWS, Azure, GCP)'
    PowerShellVersion = '7.0'
    CompatiblePSEditions = @('Core')
    RequiredModules = @('SharedToolkit')
    FunctionsToExport = '*'
    AliasesToExport = '*'
    PrivateData = @{
        PSData = @{
            Tags = @('toolkit', 'cloud', 'aws', 'azure', 'gcp')
            LicenseUri = ''
            ProjectUri = ''
            ReleaseNotes = 'Cloud management toolkit'
        }
    }
}

