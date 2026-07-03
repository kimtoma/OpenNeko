# OpenNeko

OpenNeko is a native macOS desktop pixel cat for AI agents, written in Swift
(SwiftUI + AppKit + SpriteKit). It walks on the desktop, reacts to typing
without reading key contents, detects local AI agent activity, and chats
through pluggable LLM providers. It is the Swift port of an earlier Electron
prototype — ignore any references to `npm`, Electron, or `src/` you may find
in older docs or commit history.

## Commands

```bash
xcodegen generate                 # regenerate OpenNeko.xcodeproj from project.yml
swift test                        # OpenNekoKit unit tests (SwiftPM, no Xcode needed)
./script/build_and_run.sh         # debug build + launch the app
xcodebuild -project OpenNeko.xcodeproj -scheme OpenNeko \
  -configuration Debug -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO build   # CI-equivalent app build
```

CI (`.github/workflows/ci.yml`) runs exactly: `swift test`, then
`xcodegen generate`, then the `xcodebuild` command above on `macos-latest`.
A change is safe to hand off only when `swift test` passes and the app target
still builds.

Building and running require macOS 14+, Xcode, and XcodeGen. `swift test`
covers only the `OpenNekoKit` library target.

## Layout: two layers, one rule

- `Sources/OpenNekoKit/` — pure, UI-free logic library (SwiftPM target
  `OpenNekoKit`). All state machines, parsers, settings models, protocol
  types, and copy tables live here. **This is the only tested code** —
  `Tests/OpenNekoKitTests/` mirrors it roughly one test file per source file.
- `App/` — the macOS app shell (windows, menu bar, SpriteKit scene, HTTP
  server, keyboard monitor, provider processes). Not covered by unit tests.

**The rule: put every piece of logic that can be expressed without
AppKit/SwiftUI into `OpenNekoKit` and write a test for it.** Keep `App/`
files thin adapters. When fixing a bug in `App/`, first check whether the
faulty decision logic can be extracted into `OpenNekoKit` and regression
tested there.

`project.yml` (XcodeGen) defines the app target; `Package.swift` defines
`OpenNekoKit`. The generated `OpenNeko.xcodeproj` is not committed. Bump
`MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` in `project.yml` for releases.

See `docs/ARCHITECTURE.md` for the module-by-module map and data flow, and
`docs/KIT-EXTRACTION-BACKLOG.md` for the ranked list of App/ logic still
waiting to be extracted into OpenNekoKit.

## Cat states

`CatState` (Sources/OpenNekoKit/State/CatState.swift): `idle, hover, click,
coding, typing, thinking, lunch, yawn, nap, success, error, dragging, walk,
jump`. Transitions are arbitrated by `CatStateMachine` +
`NekoStatePriority` — externally pushed agent states (e.g. `thinking` during
chat replies) outrank ambient states. Sprite frames per state come from the
active skin manifest.

## LLM design

- Provider presets: `AIProviderPreset` in `Sources/OpenNekoKit/LLM/`.
  Presets: OpenAI login (Codex CLI), Claude login (Claude CLI), Gemini login
  (Gemini CLI), Ollama, local OpenAI-compatible (LM Studio, llama.cpp, vLLM),
  Gemini API key, Claude API key, custom OpenAI-compatible endpoint.
- CLI login providers shell out to the locally installed CLI
  (`App/CodexChatProvider.swift`, `App/AgentCLIChatProvider.swift`). Never
  read or parse CLI auth files (e.g. `~/.codex/auth.json`) directly.
- HTTP providers: `App/HTTPChatProvider.swift`, with request building and
  stream parsing tested in `Sources/OpenNekoKit/LLM/HTTPChatRequestBuilder.swift`
  and `HTTPChatStreamParser.swift`.
- System prompts (skill/profile/persona context) are composed by
  `ChatPromptBuilder` in OpenNekoKit.
- API keys are stored in the macOS Keychain via `App/APIKeyStore.swift` —
  never in `settings.json`, never logged.

Do not add new provider modules or vendor-specific hook installers unless the
project explicitly chooses to broaden the provider surface.

## Skills

- Bundled skills: `App/Resources/skills/builtin/<id>/SKILL.md`
- User skills: `~/.openneko/skills/<id>/SKILL.md`
- Skill bodies are prompt instructions only. Scripts inside skill folders are
  never executed.
- Parsing/localization/catalog logic: `Sources/OpenNekoKit/Skills/`.

## Skins

- Bundled sprites: `App/Resources/sprites/<skin>/<state>_<frame>.png`
- Installed user skins: `~/Library/Application Support/openNeko/skins/<id>/`
  with `manifest.json`, `openneko-skin.json`, and transparent PNG frames.
- Skin logic: `Sources/OpenNekoKit/Skin/` (`SkinManager`, `SpriteManifest`,
  `SkinPackage`); import/packaging in `App/SkinPackageService.swift`.
- Keep reusable sprite assets; the pipeline expects transparent extracted
  frames matching the bundled naming scheme.

## State bridge (local HTTP)

`App/StateBridgeServer.swift`, default `127.0.0.1:48800`
(`OPENNEKO_PORT=48801` for a second instance):

```bash
curl -X POST http://127.0.0.1:48800/state \
  -H 'Content-Type: application/json' \
  -d '{"state":"coding","source":"agent","message":"Building"}'
```

Routes: `POST /state`; `GET /health`, `/anim`, `/pos`, `/debug/position`,
`/capture`, `/debug/settings`, `/debug/agent`, `/debug/typing`;
`POST /debug/settings/apply`, `/debug/drag`, `/debug/typing`.
Request/response shapes are modeled in `Sources/OpenNekoKit/State/`
(`StateBridgeRequest`, `AppSettingsDebugSnapshot`) — extend them there with
tests, then wire into the server.

## Invariants — do not break

- **Privacy:** typing reactions use keydown events only; never read, store,
  or transmit key contents (`App/KeyboardMonitor.swift`,
  `TypingActivityTracker`).
- **Click-through:** mouse clicks outside the cat sprite pass through to the
  desktop. Window level/collection behavior is tuned in
  `App/OpenNekoOverlayWindowPolicy.swift` — overlay windows must stay
  excluded from screen capture except the intentional `/capture` path.
- **Secrets:** API keys go to Keychain only. Never commit or log them.
- **Bubble copy:** keep UI copy short; the speech bubble is small. User-facing
  strings are localized (en/ko/ja/zh) via copy tables in OpenNekoKit
  (`NekoBubbleCopy`, `SettingsCopy`, `NekoSkillLocalization`) — update every
  language when touching copy, and update the four `README*.md` files together.
- Keep unrelated local changes out of scope.

## Releases

```bash
scripts/release-preflight.sh local|distribution|notarized
scripts/package-macos.sh          # → dist/OpenNeko-macOS-Release.{zip,dmg}
scripts/verify-macos-package.sh
```

`distribution`/`notarized` require Developer ID certs and notarization
credentials on the signing machine.
