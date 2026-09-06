# Type: Action
# Description: Interactive REPL shell for toolkit commands with history and tab completion.
param($Config, [array]$Arguments)

$C = Get-ToolkitColors
$HistoryFile = "$env:USERPROFILE\Documents\SSHToolkit_ShellHistory.log"
$Prompt = "tk> "

function Write-Prompt {
    Write-Host -NoNewline "$($C.Host)tk$($C.Reset)$($C.Action)> $($C.Reset)"
}

function Get-ToolkitCommands {
    $Cmds = @()
    $Toolkits = @("SSHToolkit", "NetToolkit", "MediaToolkit", "SecToolkit", "FileToolkit", "SharedToolkit")
    foreach ($Tk in $Toolkits) {
        $ActionsPath = "$global:SharedToolkitPath\..\$Tk\Actions"
        if (Test-Path $ActionsPath) {
            Get-ChildItem "$ActionsPath\*.ps1" -ErrorAction SilentlyContinue | ForEach-Object {
                $Cmds += "$($_.BaseName)"
            }
        }
    }
    return $Cmds | Sort-Object -Unique
}

# Register tab completion for shell
$AllCommands = Get-ToolkitCommands + @("exit", "quit", "help", "history", "clear", "cls", "health", "logs", "search", "profiles")
Register-ArgumentCompleter -CommandName "shell" -ParameterName "*" -ScriptBlock {
    param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameter)
    $AllCommands | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object { [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_) }
} | Out-Null

Write-Host "$($C.Info)Toolkit Interactive Shell$($C.Reset)"
Write-Host "$($C.Muted)Type 'help' for commands, 'exit' or 'quit' to leave$($C.Reset)"
Write-Host ""

while ($true) {
    try {
        Write-Prompt
        $Input = Read-Host
        if (-not $Input) { continue }
        $Input = $Input.Trim()
        if ($Input -in @('exit', 'quit')) { break }
        if ($Input -in @('clear', 'cls')) { Clear-Host; continue }
        if ($Input -eq 'help') {
            Write-Host "$($C.Info)Available commands:$($C.Reset)"
            $AllCommands | Sort-Object | ForEach-Object { Write-Host "  $_" }
            Write-Host ""
            Write-Host "$($C.Str)Shell commands: exit, quit, help, history, clear, cls$($C.Reset)"
            continue
        }
        if ($Input -eq 'history') {
            if (Test-Path $HistoryFile) {
                Get-Content $HistoryFile -Tail 20 | ForEach-Object { Write-Host "  $_" }
            }
            continue
        }

        # Log to history
        "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $Input" | Out-File $HistoryFile -Append -Encoding utf8

        # Parse and execute
        $Parts = $Input -split '\s+'
        $Cmd = $Parts[0]
        $Args = @()
        if ($Parts.Count -gt 1) { $Args = $Parts[1..($Parts.Count-1)] }

        # Try to dispatch to toolkit
        $Found = $false
        $Toolkits = @("SSHToolkit", "NetToolkit", "MediaToolkit", "SecToolkit", "FileToolkit", "SharedToolkit")
        foreach ($Tk in $Toolkits) {
            $ActionFile = "$global:SharedToolkitPath\..\$Tk\Actions\$Cmd.ps1"
            if (Test-Path $ActionFile) {
                $Found = $true
                try {
                    & $ActionFile -Config $Config -Arguments $Args
                } catch {
                    Write-Host "$($C.Crit)Error: $_$($C.Reset)"
                }
                break
            }
        }

        if (-not $Found) {
            Write-Host "$($C.Warn)Unknown command: $Cmd$($C.Reset)"
            Write-Host "$($C.Muted)Type 'help' for available commands$($C.Reset)"
        }
    } catch {
        if ($_.Exception.Message -like "*Interrupted*") { break }
        Write-Host "$($C.Crit)Error: $_$($C.Reset)"
    }
}

Write-Host ""
Write-Host "$($C.Info)Goodbye!$($C.Reset)"
