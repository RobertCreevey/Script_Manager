@{
    RootModule           = 'SharedToolkit.psm1'
    ModuleVersion        = '1.0.0'
    GUID                 = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890'
    Author               = 'Rober'
    Description          = 'Shared local/UI actions, events, chains, aliases, profiles - usable by all toolkits'
    PowerShellVersion    = '7.0'
    CompatiblePSEditions = @('Core')
    FunctionsToExport    = '*'
    AliasesToExport      = '*'
    CmdletsToExport      = @()
    VariablesToExport    = @()
    PrivateData          = @{
        PSData = @{
            Tags         = @('toolkit', 'automation', 'shared', 'orchestration')
            LicenseUri   = ''
            ProjectUri = 'https://github.com/RobertCreevey/Script_Manager'
            ReleaseNotes = 'Initial release with approved verb naming'
        }
    }
}