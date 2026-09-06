# Script_Manager — Modular PowerShell Automation Suite

A decoupled, profile-driven orchestration platform for LAN administration, cloud management, container ops, and Git workflows. Built on a shared core (`SharedToolkit`) with cross-toolkit chaining, dispatch, structured output, tab completion, event logging, and a plugin system.

## Quick Start

```powershell
# 1. Install with the dynamic installer (discovers all *Toolkit folders automatically)
.\Install-Toolkit.ps1 -AutoLoad -Verify

# 2. Restart PowerShell, or reload your profile
. $PROFILE

# 3. Create your first profile
New-Target -Name server1 -IP 10.0.0.50 -User admin -Key 'C:\keys\id_rsa'

# 4. Try it
server1 sys
server1 help
```

## Core Concepts

| Concept | Description |
|---------|-------------|
| **Profiles** | JSON configs that become shell aliases (`ani`, `server1`, `aws-prod`, `swarm`, `work`) |
| **Actions** | Space-separated verbs run against a profile: `server1 play video.mp4` |
| **Listeners** | Background monitors that trigger chains on events (clipboard, filewatch, procwait) |
| **Chains** | Named workflows of steps: `server1 chain new deploy NetToolkit::wol ; SharedToolkit::toast 'Wake sent' ; DockerToolkit::compose up -d` |
| **Dispatch** | One-off cross-toolkit calls: `server1 dispatch DockerToolkit ps` |
| **Aliases** | Shortcuts defined per-toolkit in `toolkit.json`; resolved automatically at dispatch time |
| **Output** | `-json`, `-csv`, `-raw`, `-table` on every action |

## Global Shared Systems

Everything below is provided by `SharedToolkit` and is available to **all** toolkits and profiles.

### Help System

```powershell
server1 help                       # Full help index for current profile
server1 help <action>              # Action-specific help
server1 help <action> <parameter>  # Parameter detail
server1 help-index                 # Interactive topic picker
server1 help-index toolkits        # All installed toolkits + versions
server1 help-index actions         # Every action across all toolkits
server1 help-index listeners       # Every listener across all toolkits
server1 help-index chains          # Chain syntax + examples
server1 help-index aliases         # Alias system + cross-toolkit dispatch
server1 help-index visual          # Verified Windows visual/interactive patterns
server1 help-index troubleshooting # Common fixes
```

### Tab Completion

```powershell
Initialize-ToolkitCompletion        # Register completion for all profile aliases
<profile> <tab>                      # Complete actions for that profile
<profile> chain run <tab>            # Complete chain names from all installed Chains\
```

### Event Logging

```powershell
Write-ToolkitEvent -Name "Deploy" -Data "v1.2.0" -Config $Config
Get-ToolkitEvents                     # Show recent bounded event ring buffer
```

Events are persisted to `$env:USERPROFILE\Documents\SSHToolkit_Events.log` and rotated automatically.

### Plugin System

Lightweight, local, single-file extensions in `~/.toolkit/plugins/*.ps1`. Auto-load on module import.

```powershell
plugin new Hello                      # Scaffold plugin file
plugin load Hello                      # Import into current session
Hello                                  # Invoke default action
plugin run Hello arg1 arg2             # Pass arguments
plugin list                            # List all plugins
plugin info Hello                       # Show metadata
plugin unload Hello                     # Remove from session
plugin reload                           # Reload all plugins
```

## Module Authoring

### Global vs Local Modules

**Global modules** (the 9 bundled toolkits):
- Install under `C:\Users\<you>\Documents\PowerShell\Modules\<ToolkitName>\`
- Auto-discovered via `Get-Module -ListAvailable`
- Can define actions, listeners, profiles, chains, and `toolkit.json`
- Share `SharedToolkit` infrastructure

**Local modules** (personal or repo-scoped):
- Same module format; can live anywhere on `PSModulePath`
- For personal scripts that still want toolkit infra (completion, help, output)
- Use `Import-Module` or add to `$PROFILE`

### Creating a New Toolkit Module

Minimum structure:

```
MyToolkit/
  MyToolkit.psd1
  MyToolkit.psm1
  toolkit.json
  Actions/
  Listeners/
  Profiles/
  Chains/           # optional
```

**1. Manifest** (`MyToolkit.psd1`)

```powershell
@{
    RootModule           = 'MyToolkit.psm1'
    ModuleVersion        = '1.0.0'
    GUID                 = '...'
    Author               = 'You'
    Description          = 'What it does'
    PowerShellVersion    = '7.0'
    CompatiblePSEditions = @('Core')
    RequiredModules      = @('SharedToolkit')
    FunctionsToExport    = '*'
    AliasesToExport      = '*'
}
```

**2. Router** (`MyToolkit.psm1`)

```powershell
$global:MyToolkitPath = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
Import-Module SharedToolkit -ErrorAction SilentlyContinue

function Register-MyProfile {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][string]$Name, [string]$IP)
    $ProfileFile = "$global:MyToolkitPath\Profiles\$Name.json"
    [PSCustomObject]@{ IP = $IP } | ConvertTo-Json | Out-File $ProfileFile -Force
    New-Alias -Name $Name -Value Invoke-MyToolkitRouter -Scope Global -Force
    Export-ModuleMember -Alias $Name
}

function Invoke-MyToolkitRouter {
    [CmdletBinding()]
    param([string]$Action, [Parameter(ValueFromRemainingArguments=$true)]$ForwardedArgs)
    $Inv = $MyInvocation.InvocationName
    if ($Inv -ne 'Invoke-MyToolkitRouter') { $ContextName = $Inv } else { $ContextName = $global:ToolContext }
    $C = if ($global:ToolColors) { $global:ToolColors } else { [PSCustomObject]@{} }
    $ProfileFile = "$global:MyToolkitPath\Profiles\$ContextName.json"
    if (-not (Test-Path $ProfileFile)) { Write-Host "$($C.Crit)[ERROR] Profile missing for '$ContextName'$($C.Reset)" ; return }
    $Config = Get-Content $ProfileFile | ConvertFrom-Json
    $ForwardedArgs = @($ForwardedArgs)
    $global:ToolContext = $ContextName
    $global:CurrentToolkitPath = $global:MyToolkitPath
    if ($Action) { $Action = Resolve-ToolkitActionName -Name $Action -ToolkitPath $global:MyToolkitPath }

    if ($Action -eq 'help' -or $Action -eq '-h' -or $Action -eq '/?' -or -not $Action) {
        Invoke-SharedHelpSystem -Caller $ContextName -TargetTopic ($ForwardedArgs -join ' ') -ChildModulePath $global:MyToolkitPath
        return
    }

    # ... your builtins and action dispatch ...
}
```

**3. Manifest aliases** (`toolkit.json`)

```json
{
  "version": "1.0.0",
  "description": "What it does",
  "actions": {
    "status": ["status", "st", "info"],
    "list":  ["list", "ls", "show"]
  },
  "listeners": {
    "watch": ["watch", "monitor", "fw"]
  },
  "builtins": {
    "help": ["help", "h", "?", "-h", "--help", "/?"],
    "config": ["config", "cfg", "settings"]
  },
  "parameters": {
    "status": {
      "path": ["path", "p", "file", "f"]
    }
  }
}
```

**4. Actions** (`Actions/<action>.ps1`)

```powershell
# Type: Action
# Description: What this does.
param($Config, [array]$Arguments)
$C = Get-ToolkitColors
$Path = $Arguments[0]
Write-Host "$($C.Action)Status:$($C.Reset) $Path"
```

## Chaining Deep-Dive

### Chain Storage

Chains are JSON files in any toolkit's `Chains/` folder. `Get-ToolkitChainDirs` searches:
1. The current toolkit's `Chains/`
2. Every installed toolkit's `Chains/`
3. `SharedToolkit/Chains/`

### Creating Chains

```powershell
# Wake machine, notify, start containers
server1 chain new deploy `
  NetToolkit::wol ; `
  SharedToolkit::toast 'WOL sent' ; `
  DockerToolkit::compose up -d

# Local-only steps (no Toolkit:: prefix) run in the active toolkit's context
server1 chain new healthcheck sys ; disk ; logs

# Run
server1 chain run deploy -Force

# Dry run
server1 chain run deploy -DryRun
```

### Step Syntax

| Step form | Meaning |
|-----------|---------|
| `actionName arg1 arg2` | Local action in current toolkit |
| `ToolkitName::actionName args` | Cross-toolkit action |
| `ToolkitName:actionName args` | Same as above |

### Scheduled Chains

```powershell
# Run chain every 15 minutes via Task Scheduler
server1 schedule add deploy 15

# List scheduled chains
server1 schedule list

# Remove
server1 schedule remove deploy
```

### Chain Events

Chains emit events you can hook:
- `ChainCreated`
- `ChainRun`
- `ChainAborted`

### Alert + Chain Integration

```powershell
server1 alert diskfull
# Shows interactive popup; buttons map to chains:
#   Cleanup -> cleanup chain
#   RestartSvc -> restartsvc chain
#   Ignore -> noop
```

## Profiles Deep-Dive

### Creating Profiles

Each toolkit has its own profile command:

```powershell
# SSH target
New-Target -Name server1 -IP 10.0.0.50 -User admin -Key 'C:\keys\id_rsa'

# Docker host
Register-DockerProfile -Name swarm -Host tcp://10.0.0.10:2376

# Cloud
Register-CloudProfile -Name aws-prod -Provider aws -Region us-east-1 -Profile default

# Git workspace
Register-GitProfile -Name work -Path 'C:\Projects' -User 'you' -Email 'you@example.com'
```

### Configuring Profiles

```powershell
server1 config view
server1 config set IP 10.0.0.100
server1 config set User admin
```

### Global Profile Management

```powershell
profiles list                                    # List all profiles across all toolkits
profiles show -name server1                      # Show one profile JSON
profiles create -toolkit SSHToolkit -name x
# Then configure via the profile alias:
x config set IP 1.2.3.4
x config set User admin
profiles delete -toolkit SSHToolkit -name x
profiles export -name server1 -json > backup.json
# profiles import -toolkit SSHToolkit -json (Get-Content backup.json)  # planned for v1.1
```

### Using Profiles

Once created, a profile becomes a **global shell alias**. Use it from any toolkit:

```powershell
server1 sys                          # SSH system summary
server1 play video.mp4               # Remote play
server1 chain run deploy             # Run chain in SSH context
server1 dispatch DockerToolkit ps    # Cross-toolkit from SSH context
```

## Output Formats

Every action supports structured output:

```powershell
server1 instances -json    # JSON
server1 instances -csv     # CSV
server1 instances -raw     # Pipe-friendly text
server1 instances -table   # Formatted table (default)

# Pipeline integration
server1 instances -json | ConvertFrom-Json | Where-Object { $_.State -eq 'running' }
Get-Process | Format-ToolOutput -Format json -Properties Name,Id,CPU
```

## Help Index Topics

```
toolkits        - All installed toolkits with summaries
actions         - All actions across all toolkits (with aliases)
listeners       - All listeners across all toolkits
builtins        - Built-in commands per toolkit
switches        - Global and action-specific switches
parameters      - Parameters for a specific action
chains          - Chain syntax and management
aliases         - Alias system and cross-toolkit dispatch
profiles        - Profile management commands
dispatch        - Cross-toolkit action dispatch
visual          - Visual/interactive methods (play, popup, msg)
troubleshooting - Common issues and solutions
examples        - Auto-generated examples from toolkit.json
```

## Example Workflows

### Deploy & Verify
```powershell
server1 chain new deploy `
  NetToolkit::wol ; `
  SharedToolkit::toast "WOL sent" ; `
  SSHToolkit::play "C:\boot.mp4" ; `
  DockerToolkit::compose up -d

server1 chain run deploy -Force
```

### Cloud Inventory
```powershell
aws-prod instances -json | ConvertFrom-Json | Where-Object { $_.State -eq 'running' }
aws-prod storage ls my-bucket --prefix logs/ -csv | Import-Csv
aws-prod costs -csv > billing.csv
```

### Git Release Flow
```powershell
work branch create release/v1.2.0
work commit -m "Release 1.2.0" -a
work tag create v1.2.0 -m "Release 1.2.0"
work push origin main --tags
```

### Alert-Driven Remediation
```powershell
server1 alert diskfull
# User clicks "Cleanup" in popup -> runs cleanup chain
```

### Clipboard-Triggered Deployment
```powershell
server1 clipboard deploy
# When an IP is copied, triggers the deploy chain automatically
```

## Configuration

```powershell
# View/edit active profile
server1 config view
server1 config set IP 10.0.0.100

# Manage profiles globally
profiles list
profiles show -name server1
profiles export -name server1 -json > backup.json
```

## Architecture

```
SharedToolkit (core — always loaded)
  ├── Colors/themes (Get-ToolkitColors)
  ├── Help system (Invoke-SharedHelpSystem, help-index)
  ├── Event log (Write-ToolkitEvent, bounded ring buffer, rotation)
  ├── Dispatch (Invoke-ToolkitContextAction, Invoke-CrossToolkitAction)
  ├── Alias resolution (Resolve-ToolkitActionName)
  ├── Output formatting (Format-ToolOutput: json/csv/raw/table)
  ├── Argument parsing (Get-ActionArguments)
  ├── Chain discovery (Get-ToolkitChainDirs)
  ├── Toolkit discovery (Get-ToolkitInstallPath)
  ├── Plugins (~/.toolkit/plugins/*.ps1 auto-load)
  ├── Tab completion (Initialize-ToolkitCompletion)
  └── Bounded event queue + module unload cleanup

Each Child Toolkit:
  ├── toolkit.json (alias lists: actions, params, switches, listeners, builtins)
  ├── Router (context-aware, profile-driven, alias-resolving)
  ├── Actions/ (space-separated verbs)
  ├── Listeners/ (event-driven)
  ├── Profiles/ (JSON -> global aliases)
  └── Chains/ (cross-toolkit workflows)
```

## Requirements

- PowerShell 7+
- Windows 10/11 (visual actions use Windows ScheduledTasks)
- SSH client (`ssh`, `scp` in PATH)
- Docker CLI (DockerToolkit)
- Git CLI (GitToolkit)
- AWS CLI / Azure CLI / gcloud (CloudToolkit)

## Install for Development

```powershell
# From repo root: copy/symlink into your Modules folder, then:
Import-Module .\SharedToolkit\SharedToolkit.psd1 -Force
Import-Module .\SSHToolkit\SSHToolkit.psd1 -Force
Initialize-ToolkitCompletion

# Run tests
Invoke-Pester .\Tests -Output Detailed
```

## Contributing / Module Authoring

See the **Module Authoring** section above for how to create a new toolkit module. The system is designed so that any folder matching `*Toolkit` on `PSModulePath` is discovered automatically.

## License

MIT
