@{
    RootModule = 'GitToolkit.psm1'
    ModuleVersion = '1.0.0'
    GUID = 'c9d0e1f2-a3b4-5678-2345-901234567890'
    Author = 'Rober'
    Description = 'Git repository operations'
    PowerShellVersion = '7.0'
    CompatiblePSEditions = @('Core')
    RequiredModules = @('SharedToolkit')
    FunctionsToExport = '*'
    AliasesToExport = '*'
    PrivateData = @{
        PSData = @{
            Tags = @('toolkit', 'git', 'version-control', 'devops')
            LicenseUri = 'https://github.com/RobertCreevey/Script_Manager/blob/master/LICENSE'
            ProjectUri = 'https://github.com/RobertCreevey/Script_Manager'
            ReleaseNotes = 'Git operations toolkit'
        }
    }
}

