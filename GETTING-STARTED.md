# Getting Started with Script_Manager

A 5-minute walkthrough to get Script_Manager installed, create your first
profile, and start using the help system.

## 1. Install

Install everything with the dynamic one-command installer (discovers all
`*Toolkit` folders automatically — no list to maintain):

```powershell
.\Install-Toolkit.ps1 -AutoLoad -Verify
```

That copies the modules to your `Documents\PowerShell\Modules`, wires up your
`$PROFILE` for auto-load, and verifies each module imports. New toolkits are
picked up automatically on the next install.

Preview first or install to a custom location:

```powershell
.\Install-Toolkit.ps1 -Destination .\LocalModules -DryRun
.\Install-Toolkit.ps1 -Toolkits SSH,Net,Docker -AutoLoad
```

## 2. Reload

Restart PowerShell, or run:

```powershell
. $PROFILE
```

## 3. Create your first profile

Each toolkit has its own profile command:

```powershell
# SSH target
New-Target -Name server1 -IP 10.0.0.50 -User admin -Key 'C:\keys\id_rsa'

# Docker host
Register-DockerProfile -Name swarm -Host tcp://10.0.0.10:2376

# Cloud
Register-CloudProfile -Name aws-prod -Provider aws -Region us-east-1

# Git workspace
Register-GitProfile -Name work -Path 'C:\Projects' -User 'you' -Email 'you@example.com'
```

That creates a global alias, so `<profile> <action>` now routes to that context.

## 4. Use it

```powershell
server1 sys                        # remote system summary
server1 snap screenshot.png        # silent remote screenshot
server1 play 'C:\Videos\demo.mp4'  # force-play video on remote screen
server1 config view                # inspect profile config
```

## 5. Get help (don’t memorize commands)

Every profile exposes a built-in `help` system sourced from `toolkit.json`:

```powershell
server1 help                       # full index
server1 help sys                   # help for one action
server1 help-index actions         # every action across all toolkits
server1 help-index toolkits        # every installed toolkit + version
server1 registry                   # same, as a data table
```

## 6. Compose with chains

```powershell
server1 chain new deploy `
  NetToolkit::wol ; `
  SharedToolkit::toast 'WOL sent' ; `
  DockerToolkit::compose up -d

server1 chain run deploy -Force
```

## 7. Cross-toolkit dispatch

```powershell
server1 dispatch NetToolkit wol
server1 dispatch SharedToolkit toast 'Hello from dispatch'
```

## 8. Extend with a plugin

Plugins live in `~/.toolkit/plugins` and auto-load on module import.

```powershell
plugin new Hello
plugin load Hello
Hello
```

See [Plugins.md](docs/Plugins.md) for the plugin authoring contract.

## Troubleshooting

- `The term 'server1' is not recognized` → run `. $PROFILE`, or confirm
  `Import-Module SSHToolkit` is in your profile.
- SSH actions fail → confirm `ssh`/`scp` are on PATH and the key is reachable.
- Tab completion not working → confirm `Initialize-ToolkitCompletion` ran.
- Path-not-found errors after moving the repo → the framework now discovers
  installed toolkits dynamically via `PSModulePath`; no hard-coded paths remain.
