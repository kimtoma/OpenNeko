# OpenNeko Architecture

Native macOS app (Swift 5.10, macOS 14+). Two layers:

```
App/                      macOS shell (AppKit + SwiftUI + SpriteKit) — untested
Sources/OpenNekoKit/      pure logic library (SwiftPM) — unit tested
Tests/OpenNekoKitTests/   ~1 test file per OpenNekoKit source file
```

`App/OpenNekoApp.swift` is the composition root: `AppDelegate` wires the
windows, monitors, providers, state bridge server, and menu bar together at
launch. It is the largest file in the repo; prefer adding logic to
OpenNekoKit and calling it from here rather than growing this file.

## Subsystems

### State (Sources/OpenNekoKit/State/, App/CatScene.swift, App/CatWindow.swift)

- `CatState` — the 14 sprite states (`idle, hover, click, coding, typing,
  thinking, lunch, yawn, nap, success, error, dragging, walk, jump`).
- `CatStateMachine` — owns the current state and transition rules.
- `NekoStatePriority` — arbitration: which incoming state may override the
  current one (e.g. `thinking` from a chat reply outranks ambient typing).
- `TypingActivityTracker` / `TypingPulseDetector` — turn keydown timestamps
  into typing activity, feeding `typing`/`coding` states.
- `CatAutonomousBehavior` — idle-time wandering (walk/jump/nap/yawn...).
- `CatLayoutMetrics`, `CatDragGeometry` — window sizing and drag math.
- `StateBridgeRequest` — decodes `POST /state` bodies.
- Rendering: `App/CatScene.swift` (SpriteKit) inside `App/CatWindow.swift`,
  a transparent always-on-top window. `App/OpenNekoOverlayWindowPolicy.swift`
  keeps overlay windows out of screen capture and clicks passing through
  outside the sprite.

### Input monitoring (App/KeyboardMonitor.swift, App/InputMonitoringPermissionController.swift)

Global keydown monitor → timestamps only. **Key contents are never read.**
Permission UX logic is testable in
`Sources/OpenNekoKit/Permissions/InputMonitoringPermissionMenu.swift`.

### Agent detection (App/AgentProcessMonitor.swift, Sources/OpenNekoKit/Agents/AgentProcessDetector.swift)

Polls local processes to detect running AI agents (Cursor, Codex, Gemini,
Claude, Antigravity, Kiro, ...) and drives `coding`/`thinking` states.
Matching rules live in `AgentProcessDetector` (tested).

### LLM chat (Sources/OpenNekoKit/LLM/, App/*ChatProvider.swift)

- `AIProviderPreset` — the preset catalog (CLI logins, Ollama, local
  OpenAI-compatible, API keys, custom endpoint) and per-preset defaults.
- `AIProviderDetection` / `AIProviderReadiness` / `AIProviderConnectionTestStatus`
  — detect installed CLIs and report connection-test state to Settings.
- `ChatPromptBuilder` — composes system prompt from skill + profile +
  persona + language.
- `HTTPChatRequestBuilder` / `HTTPChatStreamParser` — OpenAI-compatible
  request/stream handling (pure, tested); `App/HTTPChatProvider.swift` does
  the actual URLSession work.
- `App/CodexChatProvider.swift`, `App/AgentCLIChatProvider.swift` — shell out
  to `codex` / `claude` / `gemini` CLIs; `ProcessPathEnvironment` (tested)
  builds the PATH for finding them. Never parse CLI auth files.
- `ChatTranscriptStore` — persisted chat history shown by
  `App/ChatHistoryWindowController.swift`.
- `App/APIKeyStore.swift` — Keychain storage for API keys.

### Chat UI (App/CatChatWindow.swift, App/CatBubbleWindow.swift)

Bubble shows short replies; chat window handles input, slash commands, and
skill invocation. Bubble copy strings: `NekoBubbleCopy` (localized en/ko/ja/zh).

### Skills (Sources/OpenNekoKit/Skills/)

`NekoSkillCatalog` merges bundled skills
(`App/Resources/skills/builtin/*/SKILL.md`) with user skills
(`~/.openneko/skills/*/SKILL.md`). `NekoSkillManifestParser` parses SKILL.md
frontmatter; `SlashCommand` maps chat input to skills; `NekoSkillLocalization`
localizes names. Skill bodies are prompt text only — never executed.

### Skins (Sources/OpenNekoKit/Skin/, App/SkinPackageService.swift)

`SkinManager` resolves the active skin (bundled sprites, external folder, or
installed skins in `~/Library/Application Support/openNeko/skins/<id>/`).
`SpriteManifest` maps state → frame filenames. `SkinPackage` handles
`.openneko-skin` / `.zip` import and the `.openneko-skin-request` export.

### Settings (Sources/OpenNekoKit/Settings/, App/SettingsView.swift)

`AppSettings` is the persisted model (JSON in
`~/Library/Application Support/openNeko/`, migrated from the Electron app).
`SettingsDraftSynchronization` reconciles the Settings window draft with live
state; `SettingsPane`/`SettingsCopy` define panes and localized labels;
`AppLanguage` the language options; `LaunchAtLoginSetting` +
`App/LaunchAtLoginController.swift` handle login items. API keys are NOT in
AppSettings — Keychain only.

### State bridge server (App/StateBridgeServer.swift)

Plain socket HTTP server on `127.0.0.1:48800` (`OPENNEKO_PORT` overrides).
Routes: `POST /state`, `GET /health|/anim|/pos|/debug/position|/capture|
/debug/settings|/debug/agent|/debug/typing`, `POST /debug/settings/apply|
/debug/drag|/debug/typing`. `/capture` uses `App/WindowCapture.swift`.
Payload types live in OpenNekoKit (`StateBridgeRequest`,
`AppSettingsDebugSnapshot`) so they stay tested.

### Neighbors (Sources/OpenNekoKit/Neighbors/, App/NeighborNetwork.swift, App/GuestCatWindow.swift)

LAN discovery + visits: `NeighborProtocol` defines the wire messages
(tested), `NeighborSettings` the config, `NeighborEventPresentation` the
user-facing copy. `App/NeighborNetwork.swift` does Bonjour/networking;
`GuestCatWindow` renders a visiting cat.

### Updates & release (App/GitUpdateController.swift, Sources/OpenNekoKit/Updates/)

`AppUpdateDecision` (tested) decides when to offer updates. Release scripts:
`scripts/release-preflight.sh`, `scripts/package-macos.sh`,
`scripts/verify-macos-package.sh`; icon/DMG asset generators also in
`scripts/`. Version numbers live in `project.yml`.

## Data flow at a glance

```
keydown ──▶ KeyboardMonitor ──▶ TypingActivityTracker ─┐
agent process poll ──▶ AgentProcessDetector ───────────┤
POST /state ──▶ StateBridgeServer ──▶ StateBridgeRequest ─┤──▶ NekoStatePriority
chat reply lifecycle (thinking/success/error) ─────────┘        │
                                                                ▼
                                              CatStateMachine ──▶ CatScene
                                                                (skin frames via
                                                                 SkinManager/SpriteManifest)

chat input ──▶ SlashCommand/NekoSkillCatalog ──▶ ChatPromptBuilder
          ──▶ provider (CLI process | HTTPChatProvider) ──▶ bubble + ChatTranscriptStore
```

## Change checklist

1. New logic → OpenNekoKit + test; `App/` stays a thin adapter.
2. `swift test` green, then `xcodegen generate` + `xcodebuild` build green
   (CI mirrors exactly this).
3. User-visible strings → update en/ko/ja/zh copy tables together.
4. New settings field → `AppSettings` + draft sync + debug snapshot +
   migration behavior for existing settings.json.
5. New state bridge route → payload type in OpenNekoKit with a test, then
   wire in `StateBridgeServer`, then document in the READMEs.
6. Never touch: key-content privacy, click-through, Keychain-only secrets,
   screen-capture exclusion of overlay windows.
