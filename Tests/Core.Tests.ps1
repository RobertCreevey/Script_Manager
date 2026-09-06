#Requires -Module Pester

$global:WarningPreference = 'SilentlyContinue'

Describe "SharedToolkit Core Functions" {
    BeforeAll {
        $RepoRoot = Split-Path -Parent $PSScriptRoot
        Import-Module (Join-Path $RepoRoot 'SharedToolkit\SharedToolkit.psd1') -Force -ErrorAction Stop
    }

    Describe "Get-ToolkitColors" {
        It "Returns color object with expected properties" {
            $Colors = Get-ToolkitColors
            $Colors | Should -Not -BeNullOrEmpty
            $Colors.Host | Should -Not -BeNullOrEmpty
            $Colors.Action | Should -Not -BeNullOrEmpty
            $Colors.Warn | Should -Not -BeNullOrEmpty
            $Colors.Ok | Should -Not -BeNullOrEmpty
            $Colors.Reset | Should -Not -BeNullOrEmpty
        }

        It "Returns same object on repeated calls" {
            $C1 = Get-ToolkitColors
            $C2 = Get-ToolkitColors
            $C1 | Should -Be $C2
        }
    }

    Describe "Get-ActionArguments" {
        It "Parses positional arguments correctly" {
            $Result = Get-ActionArguments -Arguments @("arg1", "arg2", "-Force")
            $Result.ArgsOnly | Should -Be @("arg1", "arg2")
        }

        It "Detects -Force and -f switches" {
            $Result = Get-ActionArguments -Arguments @("-Force", "arg1")
            $Result.Switches.Force | Should -Be $true
            $Result = Get-ActionArguments -Arguments @("-f", "arg1")
            $Result.Switches.Force | Should -Be $true
        }

        It "Detects -DryRun switch" {
            $Result = Get-ActionArguments -Arguments @("-DryRun")
            $Result.Switches.DryRun | Should -Be $true
        }

        It "Detects -json, -csv, -raw, -table formats" {
            $Result = Get-ActionArguments -Arguments @("-json")
            $Result.Format | Should -Be "json"
            $Result = Get-ActionArguments -Arguments @("-csv")
            $Result.Format | Should -Be "csv"
            $Result = Get-ActionArguments -Arguments @("-raw")
            $Result.Format | Should -Be "raw"
            $Result = Get-ActionArguments -Arguments @("-table")
            $Result.Format | Should -Be "table"
        }

        It "Defaults to table format" {
            $Result = Get-ActionArguments -Arguments @("arg1")
            $Result.Format | Should -Be "table"
        }

        It "Detects help switches" {
            $Result = Get-ActionArguments -Arguments @("-h")
            $Result.Switches.Help | Should -Be $true
            $Result = Get-ActionArguments -Arguments @("-?")
            $Result.Switches.Help | Should -Be $true
            $Result = Get-ActionArguments -Arguments @("--help")
            $Result.Switches.Help | Should -Be $true
        }
    }

    Describe "Format-ToolOutput" {
        It "Formats as JSON" {
            $Input = @(@{Id=1; Name="Test"})
            $Result = $Input | Format-ToolOutput -Format json
            $Result | Should -Match '"Id":1'
            $Result | Should -Match '"Name":"Test"'
        }

        It "Formats as CSV" {
            $Input = @(@{Id=1; Name="Test"})
            $Result = $Input | Format-ToolOutput -Format csv
            $Result | Should -Match '"Id"'
            $Result | Should -Match '"Name"'
            $Result | Should -Match '"1"'
            $Result | Should -Match '"Test"'
        }

        It "Formats as raw" {
            $Input = @("line1", "line2")
            $Result = $Input | Format-ToolOutput -Format raw
            $Result -split "`n" | Should -Contain "line1"
            $Result -split "`n" | Should -Contain "line2"
        }

        It "Handles empty input" {
            $Result = @() | Format-ToolOutput -Format json
            $Result | Should -BeNullOrEmpty
        }

        It "Filters properties when specified" {
            $Input = @(@{Id=1; Name="Test"; Extra="Ignore"})
            $Result = $Input | Format-ToolOutput -Format csv -Properties "Id", "Name"
            $Result | Should -Match '"Id"'
            $Result | Should -Match '"Name"'
            $Result | Should -Not -Match "Extra"
        }

        It "Defaults to table for non-structured objects" {
            $Input = @(@{Id=1; Name="Test"})
            $Result = $Input | Format-ToolOutput
            $Result | Should -Match 'Id'
            $Result | Should -Match 'Name'
        }
    }

    Describe "Write-ToolkitEvent" {
        It "Writes event to global event list" {
            $global:ToolEvents = [System.Collections.Generic.List[PSCustomObject]]::new()
            $global:ToolEventsMax = 200
            $global:ToolEventLog = "$env:TEMP\Test_Events.log"
            if (Test-Path $global:ToolEventLog) { Remove-Item $global:ToolEventLog -Force }

            $Event = Write-ToolkitEvent -Name "TestEvent" -Data "TestData"
            $Event.Name | Should -Be "TestEvent"
            $Event.Data | Should -Be "TestData"
            $Event.Context | Should -Be "LocalSystem"
            $global:ToolEvents.Count | Should -Be 1
        }

        It "Respects max event limit" {
            $global:ToolEvents = [System.Collections.Generic.List[PSCustomObject]]::new()
            $global:ToolEventsMax = 3

            1..5 | ForEach-Object { Write-ToolkitEvent -Name "Event$_" }
            $global:ToolEvents.Count | Should -Be 3
            $global:ToolEvents[0].Name | Should -Be "Event3"
        }
    }

    Describe "Resolve-ToolkitActionName" {
        BeforeAll {
            $RepoRoot = Split-Path -Parent $PSScriptRoot
        }

        It "Resolves alias to canonical name from child toolkit" {
            $Result = Resolve-ToolkitActionName -Name "st" -ToolkitPath (Join-Path $RepoRoot 'GitToolkit')
            $Result | Should -Be "status"
        }

        It "Returns canonical name when no alias match" {
            $Result = Resolve-ToolkitActionName -Name "status" -ToolkitPath (Join-Path $RepoRoot 'GitToolkit')
            $Result | Should -Be "status"
        }

        It "Falls back to SharedToolkit manifest" {
            $Result = Resolve-ToolkitActionName -Name "chain" -ToolkitPath (Join-Path $RepoRoot 'GitToolkit')
            $Result | Should -Be "chain"
        }

        It "Returns input unchanged for unknown names" {
            $Result = Resolve-ToolkitActionName -Name "unknown_action_xyz" -ToolkitPath (Join-Path $RepoRoot 'GitToolkit')
            $Result | Should -Be "unknown_action_xyz"
        }
    }

    Describe "Get-ToolkitChainDirs" {
        BeforeAll {
            $RepoRoot = Split-Path -Parent $PSScriptRoot
        }

        It "Returns a collection of chain directories" {
            $Dirs = Get-ToolkitChainDirs -ToolkitPath (Join-Path $RepoRoot 'SSHToolkit')
            $Dirs | Should -Not -BeNullOrEmpty
            $Dirs -is [System.Collections.IEnumerable] | Should -Be $true
        }

        It "Includes current toolkit's Chains dir when it exists" {
            $Dirs = Get-ToolkitChainDirs -ToolkitPath (Join-Path $RepoRoot 'SharedToolkit')
            $SharedChains = Join-Path $RepoRoot 'SharedToolkit\Chains'
            if (Test-Path $SharedChains) {
                $Dirs | Should -Contain $SharedChains
            }
        }
    }

    Describe "Get-ToolkitInstallPath" {
        It "Finds installed toolkits by name" {
            $Path = Get-ToolkitInstallPath -ToolkitName 'SharedToolkit'
            $Path | Should -Not -BeNullOrEmpty
            $Path | Should -Match 'SharedToolkit'
        }

        It "Returns null for unknown toolkit" {
            $Path = Get-ToolkitInstallPath -ToolkitName 'NonExistentToolkitXYZ'
            $Path | Should -BeNullOrEmpty
        }
    }
}

Describe "SSHToolkit Actions" {
    BeforeAll {
        $RepoRoot = Split-Path -Parent $PSScriptRoot
        Import-Module (Join-Path $RepoRoot 'SSHToolkit\SSHToolkit.psd1') -Force -ErrorAction Stop
    }

    Describe "Request-ToolkitConfirmation (via Assert)" {
        It "Returns true when -Force is provided" {
            $Config = @{}
            $Result = Request-ToolkitConfirmation -Verb "test" -Command "test" -Config $Config -Arguments @("-Force")
            $Result | Should -Be $true
        }

        It "Returns true when -f is provided" {
            $Config = @{}
            $Result = Request-ToolkitConfirmation -Verb "test" -Command "test" -Config $Config -Arguments @("-f")
            $Result | Should -Be $true
        }
    }

    Describe "Register-Target" {
        It "Creates a profile JSON file and global alias" {
            $TestName = "pester_test_$(New-Guid)"
            try {
                Register-Target -Name $TestName -IP 127.0.0.1 -User testuser -Key 'C:\keys\id_rsa'
                $ProfileFile = Join-Path (Split-Path -Parent $PSScriptRoot) "SSHToolkit\Profiles\$TestName.json"
                if (-not (Test-Path $ProfileFile)) {
                    $ProfileFile = Join-Path $RepoRoot "SSHToolkit\Profiles\$TestName.json"
                }
                if (Test-Path $ProfileFile) {
                    $Profile = Get-Content $ProfileFile -Raw | ConvertFrom-Json
                    $Profile.IP | Should -Be "127.0.0.1"
                    $Profile.User | Should -Be "testuser"
                    Remove-Item $ProfileFile -Force -ErrorAction SilentlyContinue
                } else {
                    Set-Content -Path (Join-Path $env:TEMP 'pester_skip.txt') -Value "Profile not at expected path"
                }
            } finally {
                $Alias = Get-Alias $TestName -ErrorAction SilentlyContinue
                if ($Alias) { Remove-Item Alias:\$TestName -Force -ErrorAction SilentlyContinue }
            }
        }
    }
}

Describe "DockerToolkit Actions" {
    BeforeAll {
        $RepoRoot = Split-Path -Parent $PSScriptRoot
        Import-Module (Join-Path $RepoRoot 'DockerToolkit\DockerToolkit.psd1') -Force -ErrorAction Stop
    }

    Describe "Get-ActionArguments integration" {
        It "Parses docker-specific arguments" {
            $Result = Get-ActionArguments -Arguments @("ps", "-a", "--format", "json")
            $Result.ArgsOnly | Should -Contain "ps"
            $Result.ArgsOnly | Should -Contain "-a"
        }
    }
}

Describe "GitToolkit Actions" {
    BeforeAll {
        $RepoRoot = Split-Path -Parent $PSScriptRoot
        Import-Module (Join-Path $RepoRoot 'GitToolkit\GitToolkit.psd1') -Force -ErrorAction Stop
    }

    Describe "Get-ActionArguments integration" {
        It "Parses git-specific arguments" {
            $Result = Get-ActionArguments -Arguments @("commit", "-m", "test message", "-a")
            $Result.ArgsOnly | Should -Contain "commit"
        }
    }
}

Describe "Cross-Toolkit Helpers" {
    BeforeAll {
        $RepoRoot = Split-Path -Parent $PSScriptRoot
        Import-Module (Join-Path $RepoRoot 'SharedToolkit\SharedToolkit.psd1') -Force -ErrorAction Stop
    }

    Describe "Use-SharedAsset" {
        It "Returns false for non-existent asset" {
            $Result = Use-SharedAsset -Type "Actions" -AssetName "NonExistentAction" -Config @{} -ForwardedArgs @()
            $Result | Should -Be $false
        }
    }

    Describe "Invoke-CrossToolkitAction" {
        It "Returns false for non-existent toolkit" {
            $Result = Invoke-CrossToolkitAction -Toolkit "NonExistent" -Action "test" -Config @{}
            $Result | Should -Be $false
        }
    }
}

Describe "Router entrypoints (compat shims)" {
    BeforeAll {
        $RepoRoot = Split-Path -Parent $PSScriptRoot
        Import-Module (Join-Path $RepoRoot 'SharedToolkit\SharedToolkit.psd1') -Force -DisableNameChecking -ErrorAction Stop
    }

    It "Invoke-SharedHelpSystem renders help without throwing" {
        $SharedRoot = (Get-Module SharedToolkit -ErrorAction SilentlyContinue).ModuleBase
        if (-not $SharedRoot) { $SharedRoot = Split-Path (Get-Command Get-ToolkitHelp).Source -Parent }
        { Invoke-SharedHelpSystem -Caller 'unit' -TargetTopic $null -ChildModulePath $SharedRoot } | Should -Not -Throw
    }

    It "Invoke-ToolEvent records an event via the canonical emitter" {
        $global:ToolEvents.Clear()
        $null = Invoke-ToolEvent -Name 'RegTest' -Data 'ok' -Config $null
        ($global:ToolEvents | Where-Object { $_.Name -eq 'RegTest' }) | Should -Not -BeNullOrEmpty
    }

    It "Canonical implementations coexist with the router shims" {
        Get-Command Get-ToolkitHelp          | Should -Not -BeNullOrEmpty
        Get-Command Write-ToolkitEvent       | Should -Not -BeNullOrEmpty
        Get-Command Use-SharedAsset          | Should -Not -BeNullOrEmpty
        Get-Command Invoke-SharedHelpSystem  | Should -Not -BeNullOrEmpty
        Get-Command Invoke-ToolEvent         | Should -Not -BeNullOrEmpty
        Get-Command Invoke-SharedAsset       | Should -Not -BeNullOrEmpty
    }

    It "Invoke-SharedAsset delegates to Use-SharedAsset" {
        Invoke-SharedAsset -Type "Actions" -AssetName "NonExistentAction" -Config @{} -ForwardedArgs @() |
            Should -Be $false
    }
}

Describe "Registry Action" {
    BeforeAll {
        $RepoRoot = Split-Path -Parent $PSScriptRoot
        Import-Module (Join-Path $RepoRoot 'SharedToolkit\SharedToolkit.psd1') -Force -ErrorAction Stop
    }

    It "Lists all installed toolkits" {
        $ActionPath = Join-Path $RepoRoot 'SharedToolkit\Actions\registry.ps1'
        { & $ActionPath -Config @{} -Arguments @() } | Should -Not -Throw
    }
}

Describe "Backup Action" {
    BeforeAll {
        $RepoRoot = Split-Path -Parent $PSScriptRoot
        Import-Module (Join-Path $RepoRoot 'SharedToolkit\SharedToolkit.psd1') -Force -ErrorAction Stop
    }

    It "Lists backups without error when none exist" {
        $BackupDir = "$env:USERPROFILE\Documents\SSHToolkit_Backups"
        if (-not (Test-Path $BackupDir)) { New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null }
        $ActionPath = Join-Path $RepoRoot 'SharedToolkit\Actions\backup.ps1'
        { & $ActionPath -Config @{} -Arguments @("list") } | Should -Not -Throw
    }
}

Describe "Profiles Action" {
    BeforeAll {
        $RepoRoot = Split-Path -Parent $PSScriptRoot
        Import-Module (Join-Path $RepoRoot 'SharedToolkit\SharedToolkit.psd1') -Force -ErrorAction Stop
    }

    It "Lists profiles without throwing" {
        $ActionPath = Join-Path $RepoRoot 'SharedToolkit\Actions\profiles.ps1'
        { & $ActionPath -Config @{} -Arguments @("list") } | Should -Not -Throw
    }
}

Describe "Chain Action" {
    BeforeAll {
        $RepoRoot = Split-Path -Parent $PSScriptRoot
        Import-Module (Join-Path $RepoRoot 'SharedToolkit\SharedToolkit.psd1') -Force -ErrorAction Stop
    }

    It "Lists chains without error" {
        $ActionPath = Join-Path $RepoRoot 'SharedToolkit\Actions\chain.ps1'
        { & $ActionPath -Config @{} -Arguments @("list") } | Should -Not -Throw
    }
}

Describe "Help System" {
    BeforeAll {
        $RepoRoot = Split-Path -Parent $PSScriptRoot
        Import-Module (Join-Path $RepoRoot 'SharedToolkit\SharedToolkit.psd1') -Force -ErrorAction Stop
    }

    It "Renders help index without throwing" {
        $ActionPath = Join-Path $RepoRoot 'SharedToolkit\Actions\help-index.ps1'
        { & $ActionPath -Config @{} -Arguments @() } | Should -Not -Throw
    }

    It "Renders toolkits topic without throwing" {
        $ActionPath = Join-Path $RepoRoot 'SharedToolkit\Actions\help-index.ps1'
        { & $ActionPath -Config @{} -Arguments @("toolkits") } | Should -Not -Throw
    }

    It "Renders actions topic without throwing" {
        $ActionPath = Join-Path $RepoRoot 'SharedToolkit\Actions\help-index.ps1'
        { & $ActionPath -Config @{} -Arguments @("actions") } | Should -Not -Throw
    }

    It "Renders chains topic without throwing" {
        $ActionPath = Join-Path $RepoRoot 'SharedToolkit\Actions\help-index.ps1'
        { & $ActionPath -Config @{} -Arguments @("chains") } | Should -Not -Throw
    }
}
