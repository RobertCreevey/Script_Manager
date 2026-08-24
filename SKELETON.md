# Toolkit Architecture — Single Source of Truth (Skeleton)

## Overview
Decoupled, profile-driven, event-orchestration toolkit suite for LAN administration over SSH.
- **SharedToolkit** (parent): Local/UI actions usable by any sibling toolkit
- **Child Toolkits**: SSHToolkit, NetToolkit, MediaToolkit, SecToolkit, FileToolkit, CloudToolkit, DockerToolkit, GitToolkit
- **Syntax**: `SPACE`-separated: `ani play "C:\x.mp4"`, `ani toast "t" "m"`, `ani config set IP 10.0.0.140`
- **Profiles**: JSON files creating global aliases (`ani`, `alice`, `router`, etc.)
- **Chaining**: `Toolkit::Action` syntax, cross-toolkit composition via `chain` action

---

## Directory Structure
```
Documents/PowerShell/Modules/
├── SharedToolkit/
│   ├── SharedToolkit.psm1              # Core: colors, help, events, dispatch, alias resolver
│   ├── toolkit.json                    # Manifest (actions, params, switches, listeners, builtins as alias lists)
│   ├── Actions/                        # Type: Action — local/UI commands
│   │   ├── beep.ps1
│   │   ├── toast.ps1
│   │   ├── log.ps1
│   │   ├── speak.ps1
│   │   ├── clip.ps1
│   │   ├── open.ps1
│   │   ├── now.ps1
│   │   ├── sys.ps1
│   │   ├── hash.ps1
│   │   ├── net.ps1
│   │   ├── shot.ps1
│   │   ├── timer.ps1
│   │   ├── battery.ps1
│   │   ├── procs.ps1
│   │   ├── svc.ps1
│   │   ├── theme.ps1
│   │   ├── alias.ps1
│   │   ├── events.ps1
│   │   ├── notify.ps1
│   │   ├── ask.ps1
│   │   ├── alert.ps1
│   │   ├── dashboard.ps1
│   │   ├── registry.ps1
│   │   ├── dispatch.ps1
│   │   ├── backup.ps1
│   │   ├── restore.ps1
│   │   ├── schedule.ps1
│   │   ├── history.ps1
│   │   ├── search.ps1
│   │   ├── logs.ps1
│   │   ├── health.ps1
│   │   ├── profiles.ps1
│   │   ├── shell.ps1
│   │   ├── chain.ps1
│   │   ├── alias-resolver.ps1
│   │   └── help-index.ps1
│   ├── Listeners/                      # Type: Listener — event-driven triggers
│   │   ├── clock.ps1
│   │   ├── clipboard.ps1
│   │   ├── filewatch.ps1
│   │   └── popup.ps1
│   ├── Aliases/                        # alias set <name> <cmd> → JSON files
│   ├── Chains/                         # chain new <name> steps... → JSON files
│   └── Profiles/                       # (none — Shared has no profiles)
│
├── SSHToolkit/
│   ├── SSHToolkit.psm1                 # Router + Register-Target + newtarget
│   ├── toolkit.json                    # Manifest
│   ├── Actions/                        # SSH-specific actions
│   │   ├── play.ps1                    # Force-play video (ScheduledTask, Public folder, wmplayer/Edge)
│   │   ├── snap.ps1                    # Silent screenshot → scp → cleanup
│   │   ├── apps.ps1                    # Remote open-app list
│   │   ├── lock.ps1                    # LockWorkStation
│   │   ├── time.ps1                    # w32tm resync
│   │   ├── msg.ps1                     # LAN message (msg *, WScript Popup, WTSSendMessage)
│   │   ├── popup.ps1                   # Yes/No popup with response bridge
│   │   ├── push.ps1
│   │   ├── pull.ps1
│   │   ├── run.ps1
│   │   ├── shutdown.ps1
│   │   ├── ports.ps1
│   │   ├── process.ps1
│   │   ├── service.ps1
│   │   └── disk.ps1
│   ├── Listeners/
│   │   ├── netcheck.ps1
│   │   └── procwait.ps1                # Remote process close → chain
│   ├── Profiles/
│   │   ├── ani.json                    # {"IP":"10.0.0.125","User":"sshadmin","Key":"C:\\Users\\Rober\\.ssh\\id_lan"}
│   │   └── alice.json                  # {"IP":"10.0.0.130","User":"alice","Key":"C:\\Users\\Rober\\.ssh\\id_clean"}
│   └── Chains/
│
├── NetToolkit/
│   ├── NetToolkit.psm1
│   ├── toolkit.json
│   ├── Actions/ (portscan, traceroute, sweep, wol, arp, dns, wifi, connections, publicip, gateway, macvendor)
│   ├── Listeners/
│   ├── Profiles/ (router.json)
│   └── Chains/
│
├── MediaToolkit/
│   ├── MediaToolkit.psm1
│   ├── toolkit.json
│   ├── Actions/ (audio, display, wallpaper, wincap, monitors)
│   ├── Listeners/
│   ├── Profiles/ (thispc.json)
│   └── Chains/
│
├── SecToolkit/
│   ├── SecToolkit.psm1
│   ├── toolkit.json
│   ├── Actions/ (shares, autoruns, uac, accounts, defender, firewall)
│   ├── Listeners/
│   ├── Profiles/ (host.json)
│   └── Chains/
│
├── FileToolkit/
│   ├── FileToolkit.psm1
│   ├── toolkit.json
│   ├── Actions/ (recent, treesize, dedupe, grep, find)
│   ├── Listeners/
│   ├── Profiles/ (home.json)
│   └── Chains/
│
├── CloudToolkit/
│   ├── CloudToolkit.psm1
│   ├── toolkit.json
│   ├── Actions/ (instances, storage, fn, net, db, secrets, costs)
│   ├── Listeners/
│   ├── Profiles/ (aws-prod.json, azure-dev.json, gcp-staging.json)
│   └── Chains/
│
├── DockerToolkit/
│   ├── DockerToolkit.psm1
│   ├── toolkit.json
│   ├── Actions/ (ps, images, compose, volumes, networks, logs, exec, prune)
│   ├── Listeners/
│   ├── Profiles/ (local.json, remote.json, swarm.json)
│   └── Chains/
│
└── GitToolkit/
    ├── GitToolkit.psm1
    ├── toolkit.json
    ├── Actions/ (status, diff, commit, push, pull, branch, merge, tag, log, stash)
    ├── Listeners/
    ├── Profiles/ (work.json, personal.json)
    └── Chains/
```

---

## Router Contract (All Toolkits)
Every `Toolkit.psm1` follows identical pattern:
```powershell
$global:ToolkitPath = Split-Path $MyInvocation.MyCommand.Definition -Parent
Import-Module SharedToolkit -ErrorAction SilentlyContinue

function Register-<Toolkit>Profile { ... }  # Creates profile JSON + global alias
function Invoke-<Toolkit>Router {
    param([string]$Action, [Parameter(ValueFromRemainingArguments=$true)]$ForwardedArgs)
    # 1. Resolve context from alias name ($MyInvocation.InvocationName)
    # 2. Load profile JSON → $Config
    # 3. Builtins: help, config, online, <toolkit-specific>
    # 4. Alias resolution via SharedToolkit\Aliases\*.json
    # 5. Dispatch order:
    #    a) Child Actions:     & "$ToolkitPath\Actions\$Action.ps1" -Config $Config -Args $ForwardedArgs
    #    b) Shared Actions:    Invoke-SharedAsset -Type "Actions" ...
    #    c) Child Listeners:   & "$ToolkitPath\Listeners\$Action.ps1" ...
    #    d) Shared Listeners:  Invoke-SharedAsset -Type "Listeners" ...
    #    e) Error
}
# Auto-load profiles on import
Get-ChildItem Profiles\*.json | % { New-Alias $_.BaseName -> Router; Export-ModuleMember -Alias }
New-Alias new<toolkit> -> Register-<Toolkit>Profile
Export-ModuleMember -Function * -Alias *
```

---

## Alias List Pattern (toolkit.json)
**Every discoverable entity is an alias list: `[canonical, alias1, alias2...]`**
```json
{
  "version": "1.0.0",
  "description": "...",
  "actions": {
    "instances": ["instances", "inst", "ec2", "vms", "servers", "nodes"],
    "play": ["play", "start-video", "force-play"]
  },
  "parameters": {
    "play": {
      "path": ["path", "p", "file", "f", "video"],
      "player": ["player", "pl", "engine"]
    }
  },
  "switches": {
    "Global": ["Force", "f", "DryRun", "ConfirmAnswer", "json", "csv", "raw", "table", "help", "h", "?"],
    "play": ["force", "f", "wait", "w", "fullscreen", "fs"]
  },
  "listeners": {
    "netcheck": ["netcheck", "nc", "ping-watch"],
    "procwait": ["procwait", "pw", "process-wait"]
  },
  "builtins": {
    "help": ["help", "h", "?", "-h", "--help", "/?"],
    "config": ["config", "cfg", "settings", "conf"],
    "online": ["online", "ping", "check", "health", "status"],
    "ssh": ["ssh", "shell", "terminal", "term"]
  }
}
```
**Resolution**: `Resolve-Alias -Name "inst" -AliasLists $Toolkit.Actions` → returns canonical `"instances"`

---

## Action Contract
```powershell
# Type: Action
# Description: One-line description
param($Config, [array]$Arguments)

$C = if ($global:ToolColors) { $global:ToolColors } else { [PSCustomObject]@{} }
$ArgsOnly = @($Arguments | Where-Object { $_ -notin @("-Force","-f","-json","-csv","-raw","-table","-h","-?") })
# Parse $ArgsOnly positionally or via named parameters
# Global switches: -Force/-f, -DryRun, -ConfirmAnswer, -json/-csv/-raw/-table, -help
# Confirmation: if (-not (Assert-ToolkitAction -Verb "..." -Command "..." -Config $Config -Arguments $Arguments)) { return }
# Output: Format-ToolOutput -Format $Format (json/csv/raw/table)
```

---

## Listener Contract
```powershell
# Type: Listener
# Description: One-line description
param($Config, [array]$Arguments)
# Runs in background/loop, triggers chains or actions on events
# No direct output to console typically
```

---

## Built-in Commands (Per Toolkit)
| Command | Aliases | Purpose |
|---------|---------|---------|
| `help` | h, ?, -h, --help, /? | Hierarchical help (see Help System) |
| `config view` | cfg view, settings view | Show profile parameters |
| `config set <key> <value>` | cfg set | Update profile JSON |
| `online` | ping, check, health, status | Connectivity test |
| `<toolkit-specific>` | e.g., `ssh`, `auth`, `regions`, `context`, `login` | Toolkit-specific builtins |

---

## Global Switches (All Actions)
| Switch | Aliases | Effect |
|--------|---------|--------|
| `-Force` | `-f` | Skip confirmation prompts |
| `-DryRun` | | Preview only, no execution |
| `-ConfirmAnswer <Yes/No>` | | Pre-answer confirmation |
| `-json` | | Output as JSON |
| `-csv` | | Output as CSV |
| `-raw` | | Output as raw text (pipe-friendly) |
| `-table` | | Output as formatted table (default) |
| `-help` | `-h`, `-?` | Show action-specific help |

---

## Help System — Hierarchical Navigation
Single entry: `<profile> help [topic]` → `Invoke-SharedHelpSystem`

**Levels:**
1. **`help`** (no args) — Index: builtins, child actions, shared actions, child listeners, shared listeners
2. **`help <action>`** — Plugin help: Type, Description, Syntax, Parameters (with aliases), Switches, Examples
3. **`help <action> <param>`** — Parameter detail: type, aliases, description, valid values
4. **`help <switch>`** — Switch detail
5. **`help builtin <name>`** — Builtin command detail
6. **`help listener <name>`** — Listener detail
6. **`help find <term>`** — Search across all toolkits (name + description)
7. **`help chain <name>`** — Chain steps preview
8. **`help dispatch`** — Cross-toolkit syntax: `dispatch Toolkit Action`
9. **`help alias`** — Alias system: `alias list/set/del`, chaining syntax `Toolkit::Action`
10. **`help profile`** — Profile management: `profiles list/show/create/delete/export`
11. **`help toolkits`** — List all installed toolkits with versions

**Data source**: `toolkit.json` manifests + plugin headers (`# Type:`, `# Description:`) + alias resolver

---

## Visual/Interactive Methods — Canonical Patterns (Tested & Verified)

### 1. Force-Play Video (Session 0 Isolation Bypass)
**Correct Method (Windows 10/11):**
```powershell
# Prerequisites: File in C:\Users\Public\ (accessible by ALL users)
$VideoPath = "C:\Users\Public\video.mp4"
if (Test-Path $VideoPath) {
    # Windows Media Player (preferred — native path, no URL formatting)
    $Action = New-ScheduledTaskAction -Execute "C:\Program Files\Windows Media Player\wmplayer.exe" -Argument "`"$VideoPath`" /fullscreen"
    
    # OR Microsoft Edge (guaranteed present) — MUST use file:/// URL
    # $EdgePath = 'file:///C:/Users/Public/video.mp4'
    # $Action = New-ScheduledTaskAction -Execute "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe" -Argument "--start-fullscreen `"$EdgePath`""
    
    $LoggedInUser = (Get-CimInstance Win32_ComputerSystem).UserName
    $Principal = New-ScheduledTaskPrincipal -UserId $LoggedInUser -LogonType Interactive
    Register-ScheduledTask -TaskName "ForceVideo" -Action $Action -Principal $Principal | Out-Null
    Start-ScheduledTask -TaskName "ForceVideo"
    Start-Sleep -Seconds 3
    Unregister-ScheduledTask -TaskName "ForceVideo" -Confirm:$false
}
```
**Key rules:**
- Target file **MUST** be in `C:\Users\Public\` (not admin user profile)
- Use **backticks** to escape quotes for wmplayer: `` `"$VideoPath`" ``
- Use **file:///** with **forward slashes** for Edge
- Always detect logged-in user dynamically: `(Get-CimInstance Win32_ComputerSystem).UserName`
- Always clean up: `Unregister-ScheduledTask -Confirm:$false`

### 2. Yes/No Popup with Response Bridge
```powershell
# 1. Script block for Scheduled Task
$ScriptContent = {
    $wshell = New-Object -ComObject Wscript.Shell
    $Response = $wshell.Popup("Question?", 0, "Title", 4 + 32)  # 4=Yes/No, 32=Question icon
    # Returns: 6=Yes, 7=No
    $Response | Out-File "C:\Users\Public\popup_response.txt" -Force
}
# 2. Encode + schedule
$Encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($ScriptContent))
$Action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -WindowStyle Hidden -EncodedCommand $Encoded"
$User = (Get-CimInstance Win32_ComputerSystem).UserName
$Principal = New-ScheduledTaskPrincipal -UserId $User -LogonType Interactive
Register-ScheduledTask -TaskName "InteractivePopup" -Action $Action -Principal $Principal | Out-Null
Start-ScheduledTask -TaskName "InteractivePopup"
# 3. Poll for response
while (!(Test-Path "C:\Users\Public\popup_response.txt") -and $Counter -lt 60) { Start-Sleep 1; $Counter++ }
# 4. Read + act + cleanup
```

### 3. LAN Messages (Windows 11)
| Method | Command | Notes |
|--------|---------|-------|
| `msg` (local) | `msg * "text"` | Works inside SSH session |
| `msg` (remote) | `msg /server:IP * "text"` | Needs `HKLM:\...\AllowRemoteRPC=1` |
| WScript Popup | `New-Object -ComObject Wscript.Shell; .Popup("msg",0,"title",64)` | Wrap in ScheduledTask for visibility |
| Toast | `NotifyIcon.ShowBalloonTip()` | Requires WinForms assembly |
| WTSSendMessage | P/Invoke `wtsapi32.dll` | Targets Session 1 directly, no task needed |

---

## Chaining Syntax
```powershell
# Chain definition
ani chain new deploy NetToolkit::wol ; SharedToolkit::toast "Wake sent" ; SSHToolkit::play "video.mp4"

# Chain execution
ani chain run deploy -Force -DryRun

# Cross-toolkit dispatch (one-off)
ani dispatch NetToolkit wol
ani dispatch SharedToolkit toast "Hello"
```

---

## Profiles
```powershell
# Create
newtarget -Name bob -IP 10.0.0.140 -User admin -Key "C:\path\id_rsa"
newcloud -Name aws-prod -Provider aws -Region us-east-1 -Profile prod
newdocker -Name swarm -Host tcp://10.0.0.5:2376 -Context swarm-context

# Manage
ani config view
ani config set IP 10.0.0.140
profiles list
profiles show -name ani
profiles export -name ani -json
```

---

## Events & Logging
- **Command History**: `~\Documents\SSHToolkit_CommandHistory.log` — every invocation
- **Event Log**: `~\Documents\SSHToolkit_Events.log` — structured events (ChainRun, Confirm, Notify, Error, etc.)
- **`Invoke-ToolEvent -Name <Name> -Data <Data> -Config $Config`** — emit events
- **Listeners** subscribe to events via polling or file watchers

---

## Output Formatting
```powershell
Get-Process | Format-ToolOutput -Format json -Properties Name,Id,CPU
Get-Service | Format-ToolOutput -Format csv
Get-ChildItem | Format-ToolOutput -Format raw
```

---

## Tab Completion
```powershell
# In $PROFILE after importing modules:
Import-Module SharedToolkit
Import-Module SSHToolkit
Import-Module NetToolkit
# ...
Initialize-ToolkitCompletion  # Registers completers for ALL profile aliases
```

---

## Deployment
```powershell
# Copy module folders to:
C:\Users\Rober\Documents\PowerShell\Modules\SharedToolkit\
C:\Users\Rober\Documents\PowerShell\Modules\SSHToolkit\
# ...

# $PROFILE:
Import-Module SSHToolkit -ErrorAction SilentlyContinue
Import-Module NetToolkit -ErrorAction SilentlyContinue
# ...
Initialize-ToolkitCompletion
```