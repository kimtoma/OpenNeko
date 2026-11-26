# OpenNeko

English | [한국어](README.ko.md) | [日本語](README.ja.md) | [简体中文](README.zh.md)

OpenNeko is a native macOS desktop pixel cat for AI agents. It walks on your
desktop, reacts to typing without reading key contents, listens to local agent
state, and opens a small chat bubble when you want a quick answer.

The current app is a Swift and SwiftUI macOS port of the earlier Electron
prototype.

## Features

- Transparent always-on-top desktop cat
- Sprite skins, bundled skins, and custom skin import
- Typing reactions without reading key contents
- Local AI agent activity detection for tools such as Cursor, Codex, Gemini,
  Claude, Antigravity, and Kiro
- Small chat bubble with slash commands and skill prompts
- Chat history window and click-to-copy answers
- Bonjour-based neighbor cats on the same local network
- Break reminders: after 50 minutes of nonstop typing the cat suggests a
  stretch, eye rest, or water (up to 6 a day, toggle in General settings)
- Local HTTP state bridge for automation
- Launch at login, app language, sound, skin, AI, profile, and neighbor settings
- Release ZIP and DMG packaging scripts

## Requirements

- macOS 14 or later
- Xcode
- XcodeGen
- Optional: Codex CLI login for the default OpenAI login provider
- Optional: Claude or Gemini CLI login for those login providers
- Optional: API keys for Gemini, Claude, or OpenAI-compatible endpoints

## Run From Source

```bash
xcodegen generate
swift test
./script/build_and_run.sh
```

Build directly with Xcode:

```bash
xcodebuild -project OpenNeko.xcodeproj -scheme OpenNeko -configuration Debug build
```

The Codex desktop Run action is wired to `./script/build_and_run.sh`.

## First Run

Open `OpenNeko.app`. On first launch, the onboarding flow introduces the main
features, skin selection, cat name, permissions, launch-at-login, AI connection,
and completion state.

Input Monitoring permission is required for typing reactions. OpenNeko listens
for keydown activity only; it does not read typed text.

## AI Providers

OpenNeko supports these provider presets:

- OpenAI Login (Codex): uses the local Codex CLI login session.
- Claude Login: uses a local Claude CLI login session.
- Gemini Login: uses the Gemini CLI Google login session.
- Ollama: connects to a local Ollama OpenAI-compatible server.
  No subscription? **Settings → AI → Local model setup** checks your Mac's memory and free disk, helps you install Ollama, downloads a model that fits (Apple Silicon only), and switches the cat to it.
- Local OpenAI Compatible: connects to LM Studio, llama.cpp, vLLM, or similar.
- Gemini API Key: uses `GEMINI_API_KEY` or `GOOGLE_API_KEY`.
- Claude API Key: uses `ANTHROPIC_API_KEY`.
- Custom: accepts any OpenAI-compatible base URL, API key, and model.

Saved API keys are stored in macOS Keychain, not in `settings.json`.

## Skills

Bundled and user skills are prompt instructions stored as `SKILL.md` files.
Scripts inside skills are not executed.

- Bundled skills: `App/Resources/skills/builtin/`
- User skills: `~/.openneko/skills/<id>/SKILL.md`

Use the settings window, menu bar skill menu, or slash command list in the chat
input to run a skill.

## Custom Skins

The skin settings screen supports two custom-skin paths:

- Create a request file from cat photos. This saves an `.openneko-skin-request`
  package with photos, metadata, the current manifest, and a generation prompt.
- Import a finished `.openneko-skin`, `.zip`, or skin folder.

A finished skin contains `manifest.json`, `openneko-skin.json`, and transparent
PNG frames matching the manifest filenames. Imported skins are installed under:

```text
~/Library/Application Support/openNeko/skins/<id>/
```

## State Bridge

OpenNeko listens on `127.0.0.1:48800` by default.

```bash
curl -X POST http://127.0.0.1:48800/state \
  -H 'Content-Type: application/json' \
  -d '{"state":"coding","source":"agent","message":"Building"}'
```

Debug endpoints:

- `GET /health`
- `GET /anim`
- `GET /pos`
- `GET /debug/position`
- `GET /capture`
- `GET /debug/settings`
- `POST /debug/settings/apply`
- `GET /debug/agent`
- `POST /debug/drag`
- `POST /debug/typing`

Use another local port with:

```bash
OPENNEKO_PORT=48801 /path/to/OpenNeko.app/Contents/MacOS/OpenNeko
```

### Agent notifications

OpenNeko can tell you when Claude Code or Codex finishes or needs your
approval. Copy a snippet from Settings > General > Agent notifications:

- Claude Code (`~/.claude/settings.json`): a `Notification` hook posts
  `waiting` and a `Stop` hook posts `done`.
- Codex (`~/.codex/config.toml`, top level): a `notify` command posts `done`.

The bridge also accepts `waiting`, `needs_input`, and `attention` (the cat asks
for your attention and stays up for 10 minutes) plus `done`, `finished`, and
`complete` (shown as `success`). OpenNeko never edits these files for you.

## Package

Run local release checks:

```bash
scripts/release-preflight.sh local
scripts/release-preflight.sh distribution
scripts/release-preflight.sh notarized
```

Create release ZIP and DMG packages:

```bash
scripts/package-macos.sh
```

Artifacts are written to:

- `dist/OpenNeko-macOS-Release.zip`
- `dist/OpenNeko-macOS-Release.dmg`

Validate a package:

```bash
scripts/verify-macos-package.sh
```

`distribution` and `notarized` checks require a valid Developer ID Application
certificate and Apple notarization credentials on the signing machine.

## Migration From Electron

The native app reads the previous Electron `settings.json` from:

```text
~/Library/Application Support/openNeko/
```

It preserves selected skin, AI provider preset/base URL/model, onboarding state,
launch-at-login preference, language, sound, web search, user profile, neighbor
settings, and peer identity.

Electron `safeStorage` API key ciphertext is not imported. Re-save API keys in
the AI settings screen so they are stored in macOS Keychain.

## License

OpenNeko is released under the MIT License.
