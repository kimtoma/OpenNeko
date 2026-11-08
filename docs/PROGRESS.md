# OpenNeko Progress

## Current Scope

OpenNeko is a native macOS desktop pixel cat for AI agents, written in Swift
(SwiftUI + AppKit + SpriteKit). The earlier Electron prototype has been fully
ported; this document tracks the native app.

Included:

- Transparent always-on-top desktop cat with click-through outside the sprite
- Pixel sprite renderer, bundled skins, external skin folders, and
  `.openneko-skin` import plus `.openneko-skin-request` export
- Typing reactions from keydown timing only (key contents never read)
- Local AI agent process detection (Cursor, Codex, Gemini, Claude,
  Antigravity, Kiro, ...)
- Chat bubble, chat window, slash commands, and prompt-only skills
- Provider presets: Codex/Claude/Gemini CLI logins, Ollama, local
  OpenAI-compatible, Gemini/Claude API keys, custom endpoint
- API keys in macOS Keychain; settings migrated from the Electron
  `settings.json`
- HTTP state bridge on `127.0.0.1:48800` with debug endpoints
- LAN neighbor cat visits
- Onboarding, launch-at-login, language (en/ko/ja/zh), sounds, profiles
- ZIP/DMG release packaging with preflight and verification scripts

## Validation

Run before release or PR handoff (macOS only):

```bash
swift test
xcodegen generate
xcodebuild -project OpenNeko.xcodeproj -scheme OpenNeko \
  -configuration Debug -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO build
```

Release packaging checks:

```bash
scripts/release-preflight.sh local
scripts/package-macos.sh
scripts/verify-macos-package.sh
```

## Notes

- User skills live under `~/.openneko/skills/`.
- Installed skins live under `~/Library/Application Support/openNeko/skins/`.
- `OPENNEKO_PORT` can run multiple local instances for LAN testing.
- Version numbers (`MARKETING_VERSION`, `CURRENT_PROJECT_VERSION`) live in
  `project.yml`.
- Agent-facing guides: `AGENTS.md` (canonical), `CLAUDE.md` (Claude Code
  notes), `docs/ARCHITECTURE.md` (module map).
