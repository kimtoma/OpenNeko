# Contributing to OpenNeko

Thanks for helping with OpenNeko. Bug reports, feature ideas, code changes,
translations, skins, and docs improvements are welcome.

OpenNeko is a native macOS app written in Swift (SwiftUI + AppKit +
SpriteKit). The earlier Electron prototype has been fully ported; there is no
`npm` workflow anymore.

## Local Setup

Requirements: macOS 14+, Xcode, [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```bash
git clone https://github.com/kimtoma/openNeko.git
cd openNeko
xcodegen generate          # creates OpenNeko.xcodeproj (not committed)
swift test                 # OpenNekoKit unit tests
./script/build_and_run.sh  # debug build + launch
```

## Pull Requests

- Keep changes focused; one topic per PR.
- Run `swift test` and make sure the app still builds
  (`xcodebuild -project OpenNeko.xcodeproj -scheme OpenNeko -configuration
  Debug build`) before opening a PR. CI runs the same steps.
- Put new logic in `Sources/OpenNekoKit/` with a matching test in
  `Tests/OpenNekoKitTests/`; keep `App/` files thin (see
  `docs/ARCHITECTURE.md`).
- User-visible copy is localized (en/ko/ja/zh) — update all languages, and
  keep the four `README*.md` files in sync for doc changes.
- Do not commit generated files (`OpenNeko.xcodeproj`, `dist/`), local
  settings, or API keys.

## AI Providers

The provider preset surface is intentionally curated (CLI logins, Ollama,
local OpenAI-compatible, Gemini/Claude API keys, custom endpoint). Please
discuss broader provider additions in an issue before opening a large PR.

## Skills

User skills live in:

```text
~/.openneko/skills/<skill-id>/SKILL.md
```

Skill bodies are prompt instructions. OpenNeko does not execute scripts from
skill folders. Bundled skills live in `App/Resources/skills/builtin/`.

## Skins

External skins can be tested locally under:

```text
~/Library/Application Support/openNeko/skins/<id>/
```

Each skin needs `manifest.json`, `openneko-skin.json`, and transparent PNG
frames matching the bundled sprite naming scheme
(`App/Resources/sprites/<skin>/<state>_<frame>.png`).

## Security

Never include secrets in issues, logs, screenshots, or test fixtures. API
keys are stored in the macOS Keychain (`App/APIKeyStore.swift`) — never in
`settings.json`. Typing reactions must never read key contents.
