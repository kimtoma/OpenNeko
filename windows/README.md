# OpenNeko for Windows

A native Windows port of OpenNeko: C# .NET 8 + WPF. It mirrors the macOS app's
two-layer rule:

- `src/OpenNeko.Core/` is pure logic (net8.0, no UI). It ports `OpenNekoKit`
  file by file: state machine, priorities, autonomous behavior, typing tracker,
  drag physics, layout, bubble copy, settings, provider presets, prompt
  building, HTTP request/stream parsing, CLI planning, skills, slash commands,
  daily BGM, agent detection and sound synthesis.
- `tests/OpenNeko.Core.Tests/` covers it with xUnit. It runs on any OS.
- `src/OpenNeko.Windows/` is the WPF shell, kept as thin adapters: windows, tray
  menu, low-level keyboard hook, WMI process scan, local HTTP bridge, provider
  processes, Credential Manager, and launch at login.

Sprites, bundled skills and fonts are linked from `App/Resources/`, never copied.

## Build and run

Requires Windows 10 version 2004 (build 19041) or later and the .NET 8 SDK.

```powershell
dotnet test windows/tests/OpenNeko.Core.Tests
dotnet run --project windows/src/OpenNeko.Windows
dotnet publish windows/src/OpenNeko.Windows -c Release -r win-x64 --self-contained true -p:PublishSingleFile=true
```

CI (`.github/workflows/windows.yml`) runs the Core tests, builds the app on
`windows-latest`, and uploads a self-contained `OpenNeko-Windows-x64` artifact.

The app project references the Windows Desktop framework directly (the UI is
code-only, no XAML), so the whole solution also builds on Linux and macOS, and
can cross-publish the `win-x64` app there. It only runs on Windows.

## Packaging

```bash
windows/scripts/package-windows.sh
```

This publishes a self-contained single-file build and writes, to
`windows/artifacts/`:

- `OpenNeko-Windows-x64-<version>.zip`: portable; unzip anywhere and run `OpenNeko.exe`.
- `OpenNeko-Windows-x64-<version>.msi`: per-user installer (no admin rights)
  into `%LOCALAPPDATA%\Programs\OpenNeko`, with a Start menu shortcut. Built
  with `wixl` from msitools (`apt install wixl` / `brew install msitools`)
  from `windows/installer/OpenNeko.wxs`.

Neither is code-signed yet, so Windows SmartScreen warns on first run
("More info" → "Run anyway").

## Where things live

| What | Windows | macOS equivalent |
| --- | --- | --- |
| Settings | `%APPDATA%\openNeko\settings.json` (same format) | `~/Library/Application Support/openNeko/settings.json` |
| Chat history | `%APPDATA%\openNeko\chat-history.md` | `.../openNeko/chat-history.md` |
| User skins | `%APPDATA%\openNeko\skins\<id>\` | `.../openNeko/skins/<id>/` |
| User skills | `%USERPROFILE%\.openneko\skills\<id>\SKILL.md` | `~/.openneko/skills/<id>/SKILL.md` |
| API keys | Windows Credential Manager, `openNeko:apiKey:<presetId>` | Keychain |
| Launch at login | `HKCU\...\Run\OpenNeko` | Login item |

`OPENNEKO_PORT`, `OPENNEKO_SETTINGS_PATH` and `OPENNEKO_CHAT_HISTORY_PATH`
work as on macOS. One instance runs per bridge port.

## Platform notes

- **Typing:** a `WH_KEYBOARD_LL` hook looks only at the message type
  (`WM_KEYDOWN` / `WM_SYSKEYDOWN`). It never reads the key data.
- **Click-through and capture:** the cat window is `WS_EX_TOOLWINDOW` +
  `WS_EX_NOACTIVATE`, transparent outside the sprite, and excluded from screen
  capture with `WDA_EXCLUDEFROMCAPTURE`. `GET /capture` renders the sprite
  directly, as on macOS.
- **Coordinates:** the physics runs unchanged in the macOS y-up space per
  monitor (in DIPs), and is converted to physical pixels at the edge
  (`ScreenSpace`, `MonitorFrame`). The floor is the top of the taskbar.
- **CLI providers:** `codex`, `claude` and `gemini` are found on `PATH` (with
  `PATHEXT`, so npm's `.cmd` shims work). The prompt always goes through stdin
  because `cmd.exe` cannot carry multi-line arguments. CLI auth files are never
  read.
- **Agent detection:** WMI `Win32_Process` supplies name, command line and CPU
  time; `AgentProcessDetector` applies the same patterns as macOS.

## Not yet ported

Neighbor cats (Bonjour), skin package import/export, onboarding, the
release/notarization scripts, and the neighbor settings pane. Settings written
by the macOS app (including `neighborSettings` and `peerID`) are preserved
when the Windows app saves.
