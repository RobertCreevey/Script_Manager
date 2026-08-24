@{
    RootModule = 'SharedToolkit.psm1'
    ModuleVersion = '1.0.0'
    GUID = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890'
    Author = 'Rober'
    Description = 'Shared local/UI actions, events, chains, aliases, profiles - usable by all toolkits'
    PowerShellVersion = '7.0'
    CompatiblePSEditions = @('Core')
    FunctionsToExport = @(
        'Use-SharedAsset'
        'Get-ToolkitHelp'
        'Write-ToolkitEvent'
        'Write-ToolkitError'
        'Send-ToolkitNotification'
        'Read-ToolkitPrompt'
        'Confirm-ToolkitAction'
        'Request-ToolkitConfirmation'
        'Format-ChainPreview'
        'Get-ToolStatus'
        'Invoke-CrossToolkitAction'
        'Get-ToolkitRouter'
        'Write-ToolCommand'
        'Register-ToolkitArgumentCompleter'
        'Initialize-ToolkitCompletion'
        'Format-ToolOutput'
        'Get-ToolkitColors'
        'Get-ActionArguments'
    )
    AliasesToExport = @()
    CmdletsToExport = @()
    VariablesToExport = @()
    PrivateData = @{
        PSData = @{
            Tags = @('toolkit', 'automation', 'shared', 'orchestration')
            LicenseUri = ''
            ProjectUri = ''
            ReleaseNotes = 'Initial release with approved verb naming'
        }
    }
}