# SharedToolkit / SSHToolkit — Full Expansion Plan

## Goal
Make the LAN SSH admin toolkit **production-ready and complete** per the full design in `AI_CHAT.md`. It is a **decoupled, profile-driven, event-orchestration** suite:
- `SharedToolkit` (parent/common): local/UI resources (beep, toast, log, popup, clock, clipboard + file watchers) usable by any sibling toolkit.
- `SSHToolkit` (child/network): SSH context profiles (`ani`, `alice`, `bob`…) + SSH-specific actions (play, snap, apps, lock, time, procwait, netcheck) + a universal router that **bubbles unknown actions up to Shared**.

Syntax stays `SPACE`-separated (e.g. `ani play "C:\x.mp4"`, `ani toast "t" "m"`, `ani config set IP 10.0.0.140`). Help is color-coded & hierarchical. Operations leave **no trace on the target** unless an explicit switch is used, and report status to a local log.

## Environment / Constraints
- Targets are **Windows LAN PCs** reached over key-based OpenSSH (Windows `ssh.exe`/`scp.exe`). Local OS: Windows 10/11, PowerShell 7 (`pwsh`).
- Deploy to `C:\Users\Rober\Documents\PowerShell\Modules\` (module auto-discovery requires module folder name == `.psm1` base name: `SharedToolkit/SharedToolkit.psm1`, `SSHToolkit/SSHToolkit.psm1`).
- `$PROFILE` must contain `Import-Module SSHToolkit -ErrorAction SilentlyContinue`.
- Verified local SSH keys (`C:\Users\Rober\.ssh\`): `id_lan`, `id_clean`, `id_local_test`. `ani` → `id_lan`; `alice` → `id_clean` (per chat history). Default `Register-Target` key must be `id_local_test`.
- Sandbox has **no live `pwsh`/target** → validate by `Documents` deploy + `. $PROFILE` on the real box, then run the command matrix.

## Architecture (final tree)
```
Documents/PowerShell/Modules/
├── SharedToolkit/
│   ├── SharedToolkit.psm1        # $ToolColors palette, Invoke-SharedHelpSystem, Invoke-SharedAsset
│   ├── Actions/
│   │   ├── beep.ps1   (have)     # Type: Action
│   │   ├── toast.ps1  (have)     # Type: Action
│   │   ├── log.ps1    (have)     # Type: System
│   │   └── popup.ps1  (ADD)      # Type: Action  – WScript Yes/No + response file
│   └── Listeners/
│       ├── clock.ps1      (have) # Type: Listener
│       ├── clipboard.ps1  (ADD) # Type: Listener – clipboard IP/file -> chain
│       └── filewatch.ps1  (ADD) # Type: Listener – C:\_Scripts *.mp4 -> play chain
└── SSHToolkit/
    ├── SSHToolkit.psm1         # router + Register-Target + newtarget + autoload (REFINE)
    ├── Actions/
    │   ├── play.ps1   (REWRITE) # Type: Action  (Windows paths, ScheduledTask, log)
    │   ├── snap.ps1   (ADD)     # Type: Action  – silent screenshot -> scp -> cleanup
    │   ├── apps.ps1   (ADD)     # Type: Action  – remote open-app list
    │   ├── lock.ps1   (ADD)     # Type: Action  – remote LockWorkStation
    │   └── time.ps1   (ADD)     # Type: Action  – remote w32tm resync
    ├── Listeners/
    │   ├── netcheck.ps1 (have)  # Type: Listener
    │   └── procwait.ps1 (ADD)   # Type: Listener – remote process close -> chain
    └── Profiles/
        ├── ani.json   (verify)  # 10.0.0.125 / sshadmin / id_lan
        └── alice.json (FIX)     # 10.0.0.130 / alice / id_clean
```
Optional Phase 2 (discussed): `chain` action + `runchain` + registry + aliases `ani.chain`/`ani.watch`/`ani.fwatch`, with standard steps `AlertBeep`→`beep`, `SendToast`→`toast`, `ConnectShell`→`ssh`, `VerifyOnline`→`online`.

## Every plugin file contract
- First two lines: `# Type: <Action|Listener|System>` and `# Description: <one line>`.
- Signature: `param($Config, [array]$Args)` (Config may be `$null` for pure-local shared actions).
- For SSH actions, read target from `$Config.IP`, `$Config.User`, `$Config.Key`.
- Self-heal: preflight `Test-Path` (local), `Test-Connection` (online), optional remote free-space; abort with clear colored message otherwise.
- No-trace: remove all remote temp files/scheduled tasks on completion; **never log to the target** — call `log` (local file `SSHToolkit_Events.log`).
- End files with a blank line.

## Router contract (REFINE `SSHToolkit.psm1`)
1. Init: `$global:SSHToolkitPath`, `Import-Module SharedToolkit -ErrorAction SilentlyContinue`.
2. `Register-Target -Name -IP -User -Key`: default `Key = "$env:USERPROFILE\.ssh\id_local_test"`; write `Profiles\$Name.json`; `New-Alias $Name -> Invoke-UniversalToolkitRouter`; `Export-ModuleMember -Alias $Name`; colorized `[✓] …`.
3. `Invoke-UniversalToolkitRouter` param: `[string]$Action, [ValueFromRemainingArguments]$ForwardedArgs` (matching the blueprint — drops fragile `Arg1/Arg2/Extra`).
4. Help route: `if ($Action -eq 'help' -or $Action -eq '-h' -or $Action -eq '/?' -or -not $Action)` → `$Topic = if ($ForwardedArgs) { $ForwardedArgs } else { $null }` → `Invoke-SharedHelpSystem -Caller $ContextName -TargetTopic $Topic -ChildModulePath $global:SSHToolkitPath`.
5. `config view` (colorized map via `$C = $global:ToolColors`), `config set [key] [value]` (`$K=$ForwardedArgs[0]`? no: `$K=$ForwardedArgs[1]`, `$V=$ForwardedArgs[2..] -join " "`, persist JSON). Keys: `IP`,`User`,`Key`.
6. `online` (ping), `ssh` (interactive shell).
7. Dispatch order (add the **Listeners** step that is currently missing):
   - child Actions: `& "$SSHToolkitPath\Actions\$Action.ps1" -Config $Config -Args $ForwardedArgs`; if found `return`.
   - Shared Actions: `Invoke-SharedAsset -Type "Actions" -AssetName $Action -Config $Config -ForwardedArgs $ForwardedArgs`; if `$true` `return`.
   - child Listeners: `& "$SSHToolkitPath\Listeners\$Action.ps1" -Config $Config -Args $ForwardedArgs`; if found `return`.
   - Shared Listeners: `Invoke-SharedAsset -Type "Listeners" -AssetName $Action -Config $Config -ForwardedArgs $ForwardedArgs`; if `$true` `return`.
   - else colored `[ERROR] could not resolve '$Action'`.
8. On import: `Get-ChildItem Profiles\*.json | ForEach { New-Alias $_.BaseName -> router ; Export-ModuleMember -Alias }`; `New-Alias newtarget -> Register-Target`; `Export-ModuleMember -Function * -Alias *`.

## Action specs (ADD / REWRITE)
- **play.ps1 (REWRITE)** — fix the broken Linux/schtasks version:
  1. `$FilePath=$Args -join " "`; preflight local `Test-Path` + `Test-Connection`; `log … "Initiating playback: $FilePath"`.
  2. `scp -i $Key "$FilePath" $User@$IP:"C:\Users\Public\$BaseName"`.
  3. **Visual fix (Session 0):** run via **Interactive Scheduled Task**, not bare `ProcessStartInfo`. `Register-ScheduledTask -TaskName "PLAY_$base" -Action (New-ScheduledTaskAction -Execute "C:\Program Files\Windows Media Player\wmplayer.exe" -Argument "`"C:\Users\Public\$base`" /fullscreen") -Principal (New-ScheduledTaskPrincipal -UserId (Get-CimInstance Win32_ComputerSystem).UserName -LogonType Interactive)`; `Start-ScheduledTask`; `Start-Sleep 6`; `Unregister-ScheduledTask -Confirm:$false`. Edge/`file:///` fallback when wmplayer missing.
  4. `ssh … "Remove-Item 'C:\Users\Public\$base' -Force"`; `log … "finished, traces erased"`.
- **snap.ps1** — silent screenshot: per-target Interactive ScheduledTask running `CopyFromScreen` → `C:\Users\Public\target_snap.png`; then `scp` it down locally; `Remove-Item` remote; `log`.
- **apps.ps1** — `ssh … "Get-Process | Where MainWindowTitle | Select Name,MainWindowTitle,Id | Format-Table"`.
- **lock.ps1** — `ssh … "rundll32.exe user32.dll,LockWorkStation"`.
- **time.ps1** — `ssh … "w32tm /resync /nowarn"` (or `net time \\host /set`).
- **popup.ps1** — `WScript.Shell.Popup($Args[0].., 0,'…',4+32)`; `6`=Yes/`7`=No to `C:\Users\Public\popup_response.txt`; ScheduledTask wrapper like play for visibility.
- **Shared popup** is SSH-specific → belongs in `SSHToolkit/Actions` (remote popup). (Pure local Yes/No not required.)

## Listener specs (ADD)
- **clipboard.ps1** (Shared) — loop `Get-Clipboard`; if matches IP/file regex, fire a supplied scriptblock/chain; `break`.
- **filewatch.ps1** (Shared) — loop `Get-ChildItem C:\_Scripts -Filter *.mp4`; on new file, `Invoke-UniversalToolkitRouter` (or call play) for the newest; `break`.
- **procwait.ps1** (SSHToolkit) — `ssh … tasklist` loop watching a process name; when it disappears, run `-Args[0]` chain; `break`.
- Keep existing **clock.ps1**, **netcheck.ps1** (verify headers only).

## Help / color (SharedToolkit.psm1)
- Keep `$global:ToolColors` palette + `Invoke-SharedHelpSystem` (3 paths: `config`, plugin-header-reader via regex `#\s*Type:\s*(\w+)`/`#\s*Description:\s*(.*)`, and index that discovers child+shared Actions **and** Listeners). Switch the header parse from `-like`/`split ":"` to the blueprint regex for robustness.
- `Invoke-SharedAsset` stays `& $TargetScript -Config $Config -Args $ForwardedArgs`.

## Profiles
- `ani.json`: `{"IP":"10.0.0.125","User":"sshadmin","Key":"C:\\Users\\Rober\\.ssh\\id_lan"}`.
- `alice.json`: `{"IP":"10.0.0.130","User":"alice","Key":"C:\\Users\\Rober\\.ssh\\id_clean"}` (fix from `id_alice`; confirm `alice` vs `localadmin` username on target).

## Validation (on the real box, after deploy + `. $PROFILE`)
- `ani help`, `ani help config`, `ani help play` → color-coded, shows plugin Types.
- `ani config view`, `alice config view` → correct values.
- `ani config set IP 10.0.0.140` → persists; `ani config view` reflects it.
- `ani online` (target offline-tolerant) → ONLINE/OFFLINE.
- `ani beep`, `ani toast "t" "m"` (verify multi-arg reaches toast via Shared), `ani log "test"`, `ani clock`, `ani netcheck`.
- `ani play "C:\_Scripts\HENRY_ASCII.mp4"` (target online) → file appears fullscreen, then **no `C:\Users\Public\*.mp4` and no leftover scheduled task** remain; `SSHToolkit_Events.log` has 2 entries.
- `ani newtarget bob -IP 10.0.0.140`, then `bob help` works.
- Add new `lock.ps1`/`apps.ps1`/`time.ps1`/`snap.ps1`/`popup.ps1` and `ani <name>` auto-works with no module edits.

## Risks / open questions
- **Live test impossible in sandbox** → rely on real-box run of the validation matrix.
- `toast.ps1` uses `Start-ThreadJob` (needs `ThreadJob` module). Guard: `if (Get-Module -ListAvailable ThreadJob) {…} else { $Toast.ShowBalloonTip(10000) }` to avoid hard failure.
- Windows `scp -i` path separators: use literal backslash `C:\Users\…` in JSON keys (forward slash currently works but is brittle).
- Session 0: visual playback **must** use Interactive Scheduled Task (the bare `ProcessStartInfo` in the chat's line ~779 regresses the "audio but no video" bug) — keep the ScheduledTask wrapper.
- `alice` username/key to be confirmed against the actual target (history implies `id_clean`; username `alice` or `localadmin`).
- Phase-2 chains (`ani.chain`/`watch`/`fwatch`, `Register-ToolkitChain`) are an explicit add — include only if desired; core file-plugin model already ships the trigger capability.
