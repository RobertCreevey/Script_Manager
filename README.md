# Toolkit — Modular PowerShell Automation Suite

A decoupled, profile-driven orchestration platform for LAN administration, cloud management, container ops, and Git workflows. Built on a shared core with cross-toolkit chaining and dispatch.

## Quick Start

```powershell
# 1. Copy module folders to your modules directory
# Source: K:\_scripts\SharedToolkit_PowerShell_Module\*
# Destination: C:\Users\<you>\Documents\PowerShell\Modules\

# 2. Add to your $PROFILE
Import-Module SharedToolkit
Import-Module SSHToolkit
Import-Module NetToolkit
Import-Module MediaToolkit
Import-Module FileToolkit
Import-Module SecToolkit
Import-Module CloudToolkit
Import-Module DockerToolkit
Import-Module GitToolkit

Initialize-ToolkitCompletion  # Enables tab completion for all profiles
```

## Core Concepts

| Concept | Description |
|---------|-------------|
| **Profiles** | JSON configs creating global aliases (`ani`, `server1`, `aws-prod`, `swarm`, `work`) |
| **Actions** | Space-separated commands: `server1 play video.mp4` |
| **Chaining** | `Toolkit::Action` syntax for cross-toolkit composition |
| **Dispatch** | One-off cross-toolkit calls: `server1 dispatch DockerToolkit ps` |
| **Output** | `-json`, `-csv`, `-raw`, `-table` on every action |

## Toolkits

| Toolkit | Purpose | Key Actions |
|---------|---------|-------------|
| **SharedToolkit** | Local/UI utilities | toast, beep, speak, clip, log, hash, timer, chain, alias, profiles, logs, health, shell |
| **SSHToolkit** | LAN SSH admin | play, snap, lock, msg, popup, push, pull, shutdown, ports, process, service, disk |
| **NetToolkit** | Network diagnostics | wol, sweep, portscan, traceroute, dns, arp, wifi, gateway, connections |
| **MediaToolkit** | Display/audio control | audio, display, monitors, wallpaper, wincap |
| **FileToolkit** | File operations | find, grep, dedupe, treesize, recent |
| **SecToolkit** | Security auditing | firewall, defender, accounts, uac, autoruns, shares |
| **CloudToolkit** | AWS/Azure/GCP | instances, storage, fn, vnet, db, secrets, costs |
| **DockerToolkit** | Container management | ps, images, compose, volumes, networks, logs, exec, prune, stats, inspect, build, pull, push, system |
| **GitToolkit** | Git operations | status, diff, commit, push, pull, branch, merge, tag, log, stash, rebase, remote, init, clone, add, reset, restore, clean, config, blame, show, bisect |

## Example Workflows

### Deploy & Verify
```powershell
# Wake machine, play boot video, start containers
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

## Help System

```powershell
server1 help                    # Full index
server1 help play               # Action help
server1 help play path          # Parameter detail
server1 help-index toolkits     # All toolkits
server1 help-index actions      # All actions
server1 help-index chains       # Chain syntax
server1 help-index visual       # Verified Windows patterns
server1 help-index troubleshooting # Common fixes
```

## Configuration

```powershell
# View/edit profile
server1 config view
server1 config set IP 10.0.0.100

# Manage profiles globally
profiles list
profiles show -name server1
profiles export -name server1 -json > backup.json
```

## Output Formats

```powershell
server1 instances -json    # JSON
server1 instances -csv     # CSV
server1 instances -raw     # Pipe-friendly text
server1 instances -table   # Formatted table (default)

# Pipeline
Get-Process | Format-ToolOutput -Format json -Properties Name,Id,CPU
```

## Requirements

- PowerShell 7+
- Windows 10/11 (SSHToolkit visual actions use Windows ScheduledTasks)
- SSH client (`ssh`, `scp` in PATH)
- Docker CLI (DockerToolkit)
- Git CLI (GitToolkit)
- AWS CLI / Azure CLI / gcloud (CloudToolkit)

## Architecture

```
SharedToolkit (core)
  ├── Colors, Help, Events, Dispatch, Alias Resolution
  ├── Format-ToolOutput (json/csv/raw/table)
  ├── Get-ToolkitColors, Get-ActionArguments
  └── Bounded event queue + module unload cleanup

Each Child Toolkit:
  ├── toolkit.json (alias lists: actions, params, switches, listeners, builtins)
  ├── Router (context-aware, profile-driven)
  ├── Actions/ (space-separated verbs)
  ├── Listeners/ (event-driven)
  ├── Profiles/ (JSON → global aliases)
  └── Chains/ (cross-toolkit workflows)
```

## License

MIT