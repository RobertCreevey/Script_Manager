# Getting Started with Toolkit

A 5-minute walkthrough to get the Toolkit suite installed, create your first
target, and start using help. If you have questions, see the full [README.md](README.md).

## 1. Install

Install everything with the dynamic one-command installer (discovers all
`*Toolkit` folders automatically — no list to maintain):

```powershell
.\Install-Toolkit.ps1 -AutoLoad -Verify
```

That copies the modules to your `Documents\PowerShell\Modules`, wires up your
`$PROFILE` for auto-load, and verifies each module imports. New toolkits are
picked up automatically on the next install.

Want to preview first or install somewhere else?

```powershell
.\Install-Toolkit.ps1 -Destination .\LocalModules -DryRun      # preview, no writes
.\Install-Toolkit.ps1 -Toolkits SSH,Net,Docker -AutoLoad      # subset by short name
.\Install-Toolkit.ps1 -Toolkits SSHToolkit                    # ...or full module name
```

## 2. Reload

Either restart PowerShell, or run:

```powershell
. $PROFILE        # dot-source to load modules in the current session
```

## 3. Understand the idea

- **Profiles** = JSON configs that become shell aliases, e.g. `server1`, `ani`,
  `aws-prod`. Each points the toolkit at a machine / cloud / container host.
- **Actions** = space-separated commands run against a profile: `server1 sys`.
- **Dispatch** = one-off calls across toolkits: `server1 dispatch DockerToolkit ps`.
- **Chaining** = compose actions: `server1 chain new deploy ... ; ` then `server1 chain run deploy`.

## 4. Create a target (your first profile)

```powershell
New-Target -Name server1 -IP 10.0.0.50 -User admin -Key 'C:\keys\id_rsa'
```

That creates the alias `server1`, so `server1 <action>` now routes over SSH to
that machine.

## 5. Get help (don't memorize commands)

Every profile exposes a built-in `help` system sourced from `toolkit.json`:

```powershell
server1 help                       # full index (builtins, actions, listeners)
server1 help sys                   # help for one action
server1 help-index actions         # every action across toolkits
server1 help-index toolkits        # every installed toolkit + version
server1 registry                   # same, as a data table
```

> Tip: `help-index` with no argument opens an interactive picker (`/?` and `-h`
> also work as shortcuts to `help`).

## 6. Try it

```powershell
server1 sys                        # remote system summary
server1 snap screenshot.png        # silent remote screenshot -> local file
server1 play 'C:\Videos\demo.mp4'  # force-play a video on the remote screen
```

## 7. Extend with a plugin

Plugins live in `~/.toolkit/plugins` and **auto-load** on module import. Add
your own in seconds:

```powershell
plugin new Hello                      # scaffolds ~/.toolkit/plugins/Hello.ps1
plugin load Hello                     # load it in the current session
Hello                                 # run its default action
plugin run Hello args...              # pass arguments
```

See [Plugins.md](docs/Plugins.md) for the plugin authoring contract.

## Troubleshooting

- `The term 'server1' is not recognized` → run `. $PROFILE`, or confirm
  `Import-Module SSHToolkit` is in your profile.
- SSH actions fail → confirm `ssh`/`scp` are on PATH and the key is reachable.
- Tab completion not working → confirm `Initialize-ToolkitCompletion` ran (the
  installer adds it; `. $PROFILE` re-runs it).
