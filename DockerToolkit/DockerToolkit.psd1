@{
    RootModule = 'DockerToolkit.psm1'
    ModuleVersion = '1.0.0'
    GUID = 'b8c9d0e1-f2a3-4567-1234-890123456789'
    Author = 'Rober'
    Description = 'Docker container management'
    PowerShellVersion = '7.0'
    CompatiblePSEditions = @('Core')
    RequiredModules = @('SharedToolkit')
    FunctionsToExport = '*'
    AliasesToExport = '*'
    PrivateData = @{
        PSData = @{
            Tags = @('toolkit', 'docker', 'container', 'kubernetes')
            LicenseUri = ''
            ProjectUri = 'https://github.com/RobertCreevey/Script_Manager'
            ReleaseNotes = 'Docker container management toolkit'
        }
    }
}

