# Plugins

User plugins extend the toolkit without editing module files. They live in
`~/.toolkit/plugins/*.ps1` and **auto-load** when `SharedToolkit` is imported
(or via `plugin load <Name>`).

## Lifecycle commands

```powershell
plugin new Hello        # scaffold ~/.toolkit/plugins/Hello.ps1 from the template
plugin load Hello       # import it into the current session
Hello                   # invoke the default action (see # Action: below)
plugin run Hello a b    # invoke with arguments
plugin info Hello       # show path + header + first lines
plugin list             # list plugin files
plugin unload Hello     # remove loaded functions
plugin reload           # reload all
```

## Authoring contract

A plugin is a `.ps1` with a header block followed by one function named **exactly
the plugin (file) name** — that function becomes the callable action.

```powershell
# Version: 1.0.0
# Description: My plugin — does X
# Author: You
# Action: MyPlugin          # <-- the default action name (the function name)

function MyPlugin {
    [CmdletBinding()]
    param(
        $Config,           # toolkit config object (often $null for local-only plugins)
        [array]$Arguments  # command arguments, already split
    )
    $C = if (Get-Command Get-ToolkitColors -ErrorAction SilentlyContinue) { Get-ToolkitColors } else {
        [PSCustomObject]@{ Action='Cyan'; Ok='Green'; Warn='Yellow'; Err='Red'; Reset='' }
    }
    Write-Host "[MyPlugin] args: $($Arguments -join ' ')" -ForegroundColor $C.Action
}
```

### Header fields
| Field | Purpose |
|-------|---------|
| `# Version:` | semver for your plugin |
| `# Description:` | one-line summary (used by `plugin info` / help search) |
| `# Author:` | your name/handle |
| `# Action:` | the default action name — must match the function name |

### Conventions
- Use `Write-Host` with `$C.Action` / `$C.Ok` / `$C.Warn` / `$C.Crit` for themed
  output (`$C.Warn` for warnings/notes, `$C.Crit` for errors).
- Keep `$Config` optional; local-only helpers can ignore it.
- Auto-load on import means functions land in the **global** scope. Unload with
  `plugin unload <Name>` to clear them.

### `plugin run` / dispatch form
`Invoke-PluginAction` resolves `run <Name> <args>` and `run <Name> <action>`
when a plugin exposes more than one callable action. For single-action plugins
the bare `<Name>` call runs the default action directly.
