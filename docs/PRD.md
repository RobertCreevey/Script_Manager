# Script_Manager — Product Requirements Document

## 1. Overview

Script_Manager is a modular PowerShell automation framework for Windows LAN administration, cloud management, container ops, and Git workflows. It provides a shared core (`SharedToolkit`) that powers 9 domain-specific toolkits, all exposed through profile-driven shell aliases and a consistent command surface.

## 2. Problem Space

- Admins/developers juggle SSH, Docker, Git, cloud CLIs, and local utilities with inconsistent interfaces.
- Scripts are often one-off, non-composable, and lack shared structure (output, logging, help, configuration).
- Tooling is typically monolithic; adding a new domain requires either hacking an existing module or building infra from scratch.

## 3. Goals

1. **Unified command surface** — one profile alias per target/host/context.
2. **Cross-toolkit composition** — chains and dispatch without leaving the shell.
3. **Shared infrastructure** — colors, help, logging, output formatting, tab completion.
4. **Modular extension** — drop a `*Toolkit` folder into `PSModulePath` and it is discovered automatically.
5. **Portable** — no hard-coded developer paths; works on any Windows 10/11 machine.

## 4. Non-Goals

- Cross-platform shell parity beyond PowerShell 7+ on Windows.
- Replacing existing CLIs (Docker, Git, AWS) — wrappers only.
- GUI application.

## 5. User Personas

| Persona | Primary Use |
|---------|-------------|
| **Windows Admin** | SSH admin, software deployment, system health, network sweeps |
| **DevOps Engineer** | Git flows, container deploy, cloud inventory |
| **Power User** | Media control, file automation, clipboard triggers, scheduling |

## 6. Core Concepts

### 6.1 Profiles
JSON configs stored in `<Toolkit>/Profiles/<name>.json`. Each profile becomes a **global shell alias** (e.g. `server1`, `aws-prod`, `work`) so any toolkit can be used as `<profile> <action>`.

### 6.2 Actions
Single-purpose commands inside `Actions/<name>.ps1`. Receive `$Config` and `[array]$Arguments`. Return objects for structured output.

### 6.3 Listeners
Background event loops in `Listeners/<name>.ps1`. Trigger chains or actions on conditions (clipboard change, new file, process exit).

### 6.4 Chains
JSON workflows in `<Toolkit>/Chains/<name>.json`. Steps can be local (`action`) or cross-toolkit (`Toolkit::action`). Run with `<profile> chain run <name> [-Force] [-DryRun]`.

### 6.5 Dispatch
One-off cross-toolkit invocation: `<profile> dispatch <Toolkit> <action> [args...]`.

### 6.6 Output Formats
Every action supports `-json`, `-csv`, `-raw`, `-table` via `Format-ToolOutput`.

## 7. System Architecture

### 7.1 SharedToolkit (Core)
- `Get-ToolkitColors` — theme-aware output colors.
- `Get-ActionArguments` — switch/format parsing.
- `Format-ToolOutput` — structured output.
- `Invoke-ToolkitContextAction` — route action in active context.
- `Invoke-CrossToolkitAction` — route action in another toolkit.
- `Resolve-ToolkitActionName` — manifest alias resolution.
- `Get-ToolkitChainDirs` — dynamic chain discovery across all installed toolkits.
- `Get-ToolkitInstallPath` — resolve toolkit install from `PSModulePath`.
- `Invoke-SharedHelpSystem` / `Get-ToolkitHelp` — hierarchical help.
- `Write-ToolkitEvent` — bounded event log + persistent file + rotation.
- `Send-ToolkitNotification` — toast / beep / TTS / interactive chain triggers.
- `Initialize-ToolkitCompletion` — tab completion for all profile aliases.
- Plugin auto-discovery from `~/.toolkit/plugins/*.ps1`.

### 7.2 Child Toolkits
Each toolkit:
- Exposes a router (`Invoke-<Toolkit>ToolkitRouter`) that sets context, resolves aliases, and dispatches to actions.
- Declares aliases in `toolkit.json`.
- Ships actions, listeners, profiles, and optional chains.

## 8. User Stories

| ID | Story | Priority |
|----|-------|----------|
| US-01 | As an admin, I want one alias per target so I don’t repeat connection details. | P0 |
| US-02 | As an admin, I want cross-toolkit chains so I can compose workflows. | P0 |
| US-03 | As a user, I want consistent `-json`/`-csv`/`-table` output from every action. | P0 |
| US-04 | As a user, I want tab completion for actions and chains. | P1 |
| US-05 | As a user, I want `help` and `help-index` to discover commands. | P1 |
| US-06 | As a developer, I want to add a new toolkit by dropping a folder into `PSModulePath`. | P1 |
| US-07 | As a user, I want plugins for lightweight local extensions without editing modules. | P2 |
| US-08 | As an admin, I want event logging for audit and replay. | P2 |
| US-09 | As a user, I want scheduled chains for periodic tasks. | P2 |
| US-10 | As a dev, I want tests that run on any machine, not just the author’s. | P1 |

## 9. Roadmap

### v1.0 (Current)
- 9 bundled toolkits
- Profile-driven dispatch
- Chains, dispatch, output formatting
- Help system + tab completion
- Plugin system
- Structured event log

### v1.1
- README / docs overhaul
- Module authoring guide
- PRD publication
- PlatyPS-based MAML help generation

### v2.0
- `about_Toolkit` conceptual help per module
- Plugin registry/discovery UI
- Remote chain execution orchestration
- Configuration validation + schema enforcement

## 10. Success Metrics

- Time to first profile: < 5 minutes
- Chain success rate: > 95% (clear error messages + dry-run)
- Module author onboarding: one `toolkit.json` + one router + one action
- Test portability: tests pass on a fresh machine with only `Pester` installed

## 11. Open Questions

- Should chains support conditional branching / loops?
- Should plugins be publishable to a central registry?
- Should cloud toolkits use credential chains (secret managers) instead of raw CLI profiles?
