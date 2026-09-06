#Requires -Module Pester
$global:WarningPreference = 'SilentlyContinue'  # toolkit cmdlets intentionally use non-approved verbs; suppress the notice across all Pester scopes for this session.

Describe "SharedToolkit Core Functions" {
    BeforeAll {
        Import-Module "K:\_scripts\SharedToolkit_PowerShell_Module\SharedToolkit\SharedToolkit.psd1" -Force
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
}

Describe "SSHToolkit Actions" {
    BeforeAll {
        Import-Module "K:\_scripts\SharedToolkit_PowerShell_Module\SSHToolkit\SSHToolkit.psd1" -Force
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
}

Describe "DockerToolkit Actions" {
    BeforeAll {
        Import-Module "K:\_scripts\SharedToolkit_PowerShell_Module\DockerToolkit\DockerToolkit.psd1" -Force
    }

    Describe "Get-ActionArguments integration" {
        It "Parses docker-specific arguments" {
            $Result = Get-ActionArguments -Arguments @("ps", "-a", "--format", "json")
            $Result.ArgsOnly | Should -Contain "ps"
        }
    }
}

Describe "GitToolkit Actions" {
    BeforeAll {
        Import-Module "K:\_scripts\SharedToolkit_PowerShell_Module\GitToolkit\GitToolkit.psd1" -Force
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
        Import-Module "K:\_scripts\SharedToolkit_PowerShell_Module\SharedToolkit\SharedToolkit.psd1" -Force
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
        Import-Module "K:\_scripts\SharedToolkit_PowerShell_Module\SharedToolkit\SharedToolkit.psd1" -Force -DisableNameChecking
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