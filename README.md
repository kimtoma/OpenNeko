# openNeko native macOS

openNeko is a native macOS desktop companion. It shows a transparent SpriteKit
pixel cat, reacts to typing without reading key contents, accepts local state
bridge events, and can start short AI chat from the cat.

This Swift port is replacing the previous Electron implementation.

## Requirements

- macOS 14 or newer
- Xcode
- XcodeGen for regenerating `OpenNeko.xcodeproj`
- Codex CLI login for the default chat provider: `codex login`
- Optional Claude Code or Gemini CLI login for those login providers
- Optional API keys for Gemini, Claude, or OpenAI-compatible endpoints

## Build

```bash
xcodegen generate
xcodebuild -project OpenNeko.xcodeproj -scheme OpenNeko -configuration Debug build
swift test
```

Run the Debug app through the project run script:

```bash
./script/build_and_run.sh
./script/build_and_run.sh --verify
```

The Codex desktop Run action is wired to `./script/build_and_run.sh`.

Capture the settings window for visual QA without macOS Screen Recording
permission:

```bash
OPENNEKO_SETTINGS_SNAPSHOT=/tmp/openneko-settings.png \
OPENNEKO_PORT=48802 \
.derivedData/Build/Products/Release/OpenNeko.app/Contents/MacOS/OpenNeko
```

## First Run

Open `openNeko.app`. The settings window opens on first launch with a Start
dashboard for typing permission, AI readiness, selected skin, neighbor status,
and the local state bridge port.

The Bridge tab shows the active loopback endpoint and a copyable `curl` example
for automation hooks.

Use the AI tab to choose a provider and press **AI 테스트** before relying on
chat. API keys are stored in macOS Keychain.

The General tab includes **AI 에이전트 자동 감지**. When enabled, openNeko
detects busy local tools such as Cursor, Codex, Claude, Gemini, Antigravity,
and Kiro and switches the cat into a working animation without requiring a
manual bridge hook.

The Neighbors tab enables Bonjour discovery for other openNeko instances on the
same local network. Presence is shared as coarse states only: idle, coding,
typing, or away.

Use the Skills tab or the menu bar **스킬** submenu to run bundled and user
`SKILL.md` prompts. User skills live in `~/.openneko/skills/<id>/SKILL.md`;
skill bodies are prompt instructions only and scripts are not executed.

## Custom Skins

The Skin settings tab supports two custom-skin paths:

- **사진으로 요청 파일 만들기**: choose cat photos and save an
  `.openneko-skin-request` file. It contains the photos, the current
  `manifest.json`, metadata, and `chatgpt-prompt.md` for ChatGPT image
  generation.
- **스킨팩 가져오기**: import a finished `.openneko-skin` file, `.zip`, or
  skin folder. Complete skins are installed under
  `~/Library/Application Support/openNeko/skins/<id>/` and immediately appear
  in the skin list.

A finished custom skin is a folder or archive containing `manifest.json`,
`openneko-skin.json`, and transparent PNG frames with the exact filenames from
the manifest. This same format can be used for paid/concierge skin creation:
receive the user's `.openneko-skin-request`, create the PNG frames, then send
back a finished `.openneko-skin` file.

The menu bar **업데이트 확인** action mirrors the old Electron git updater for
developer/git checkout installs. It checks `origin/<branch>`, blocks automatic
updates when tracked files are dirty, and relaunches through
`script/build_and_run.sh` after a fast-forward pull. Packaged ZIP/DMG builds are
not treated as git installs.

## Electron Migration

The native app reads the previous Electron `settings.json` from the same
`~/Library/Application Support/openNeko/` location. It preserves the selected
skin, AI provider preset/base URL/model, onboarding state, and launch-at-login
preference, language, sound, web search, user profile, neighbor settings, and
peer identity.

Electron `safeStorage` API key ciphertext is not imported. Re-save API keys in
the AI tab so they are stored in macOS Keychain.

## Package

Check the local machine before building release artifacts:

```bash
scripts/release-preflight.sh local
scripts/release-preflight.sh distribution
scripts/release-preflight.sh notarized
```

`distribution` and `notarized` are readiness checks. They are expected to fail
until a valid Developer ID Application certificate and notary credentials are
available on the signing machine.

Create Release ZIP and DMG packages:

```bash
scripts/package-macos.sh
```

Packages are written to:

- `dist/OpenNeko-macOS-Release.zip`
- `dist/OpenNeko-macOS-Release.dmg`

Without extra environment variables this creates a local ad-hoc signed build.
Use `CREATE_DMG=0 scripts/package-macos.sh` if you only need the ZIP.
Validate a local package with:

```bash
scripts/verify-macos-package.sh
```

Sign with a Developer ID Application certificate:

```bash
DEVELOPER_ID_APPLICATION="Developer ID Application: Your Name (TEAMID)" \
scripts/package-macos.sh
scripts/verify-macos-package.sh distribution
```

Sign, notarize, staple, and re-zip:

```bash
DEVELOPER_ID_APPLICATION="Developer ID Application: Your Name (TEAMID)" \
NOTARIZE=1 \
NOTARYTOOL_KEYCHAIN_PROFILE="openneko-notary" \
scripts/package-macos.sh
scripts/verify-macos-package.sh notarized
```

Alternatively provide `APPLE_ID`, `APPLE_TEAM_ID`, and
`APPLE_APP_SPECIFIC_PASSWORD` instead of `NOTARYTOOL_KEYCHAIN_PROFILE`.

## State Bridge

The app listens on `127.0.0.1:48800` by default.

```bash
curl -X POST http://127.0.0.1:48800/state \
  -H 'Content-Type: application/json' \
  -d '{"state":"coding","source":"agent","message":"Building"}'
```

Debug endpoints:

- `GET /health`
- `GET /anim`
- `GET /pos`
- `GET /debug/position` (alias for `/pos`)
- `GET /capture`
- `GET /debug/settings` (local QA: current settings without API keys)
- `POST /debug/settings/apply` (local QA: apply allowed settings only when `OPENNEKO_DEBUG_SETTINGS_MUTATION=1`; supports provider, skin, onboarding, skills, language, sound, web search, cat name, profile, and neighbor fields)
- `GET /debug/agent` (local QA: current agent-process activity sources)
- `POST /debug/drag` (local QA: lift, swing, drop, then verify `/debug/position`)
- `POST /debug/typing` (local QA: simulate a keydown event without reading key contents)

Use another port with:

```bash
OPENNEKO_PORT=48801 /path/to/OpenNeko.app/Contents/MacOS/OpenNeko
```

## Current Native Features

- Menu bar app with transparent always-on-top cat window
- Menu bar and cat right-click quick actions
- Native app icon and menu bar template icon
- Sprite skins, external skin folders, and selected skin persistence
- Input Monitoring permission helper
- Typing reaction without reading key contents
- Autonomous idle behaviors: hover, short walks, yawn/jump, nap, lunch, and leave-work rituals
- Local AI agent activity detection without setup scripts
- Launch at login toggle
- Local HTTP state bridge
- Bridge settings tab with copyable automation command
- Local network neighbor discovery and wave/greeting events
- Git checkout update check/apply action from the menu bar
- Chat slash commands for app actions and enabled skills
- Cat state preview menu for thinking, coding, typing, success, error, and idle states
- Bundled and user `SKILL.md` prompt skills from settings and the menu bar
- Glass settings window
- Start dashboard for first-run setup status
- Click-to-chat input window
- Codex CLI, Claude CLI, Gemini CLI, OpenAI-compatible, Gemini API, and Claude API chat providers
- AI provider readiness and connection test
- API keys stored in macOS Keychain, not in `settings.json`
