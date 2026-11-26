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
- Apple On-Device Model: replies with Apple's built-in model on macOS 26+
  Macs with Apple Intelligence turned on (no download, no key). The app
  still runs on macOS 14; the preset just reports that it is unavailable.
- Gemini API Key: uses `GEMINI_API_KEY` or `GOOGLE_API_KEY`.
- Claude API Key: uses `ANTHROPIC_API_KEY`.
- Custom: accepts any OpenAI-compatible base URL, API key, and model.

Saved API keys are stored in macOS Keychain, not in `settings.json`.

## Cat Tools

Ask the cat for a timer, a reminder, copying text, or opening a web page
("set a 3 minute timer"). The model proposes the action and the cat asks
first: click the bubble to allow it. Timers and reminders work while
OpenNeko is running. Toggle **Cat tools** in AI settings.

## Selected Text

Select text in any app, then choose **Services → openNeko: Explain /
Translate / Summarize** (or right-click → Services). The cat answers in its
bubble with your current AI provider. Only the text you send is used.
If the items don't appear right after installing, log out and back in once.

## Voice Input

Tap the 🎤 button in the chat box and speak. Dictation ends when you pause for
two seconds or tap the button again; Esc cancels and restores what you had
typed. Speech is recognized on this Mac only (macOS on-device speech recognition) and lands in
the chat field so you can fix it before sending. If the Mac can't recognize
your language on device, voice input stays off rather than sending audio to a
server. The first use asks for microphone and speech recognition permission.

## Speaking Up

Everything the cat says without being asked (break reminders, lunch and
end-of-day lines, memory suggestions, neighbor cats, routines, the what's new
tour) goes through one gate. Pick **Chattiness** in the menu: Quiet (3 a day),
Normal (8) or Chatty (15). Agent updates and routines don't count toward it.
While a meeting app (Zoom, Teams, FaceTime, Webex) is in front, or Keynote,
PowerPoint or a video player fills the screen, suggestions are skipped and
routines wait. Reply "stop" right after a suggestion and that kind of message
stays off; the Chattiness menu turns it back on.

## Memory

The cat keeps three plain Markdown files in `~/.openneko/memory/`:

- `soul.md`: the cat's personality and voice. Only you edit it; leave it
  empty for the default persona.
- `user.md`: lasting facts about you. The cat asks "remember this?" in a
  bubble and adds a line only when you click.
- `memory.md`: recent context. The cat notes it on its own (click the bubble
  to undo). When it grows past about 4 KB, the oldest lines move to
  `archive/YYYY-MM.md`; nothing is deleted.

When you mention something from an earlier chat, the cat searches the local
chat history and brings up to three related exchanges into the prompt.
Open **Memory Notes** from the menu (or Settings > Memory) to read and edit
the files. Local models always use your memory; for cloud providers you choose
what is sent (everything, soul only, or nothing). Entries that look like
passwords, keys or card numbers are refused.

## Delegated Tasks

Type `/task <what to do>` in the chat bubble, pick a project folder, and the
cat hands the task to your local Claude Code CLI inside that folder only.
Reading and editing files in the folder is allowed; anything else (shell
commands, network) comes back as an approval question: click the bubble to
allow or deny it for this task. Home, root, and system folders are refused.
Every step is written to `~/Library/Application Support/openNeko/agent-activity.jsonl`
(`/tasklog` opens it). `/task stop` cancels.

## Routines

Settings → Day → Routines lets the cat run jobs at set times while OpenNeko is
running, such as a weekday morning briefing or an end-of-day wrap-up. A
routine without a folder sends its prompt to your AI provider and answers in
the bubble. A routine with a folder runs Claude Code read-only inside that
folder (for example, summarizing yesterday's commits); anything else asks you
first. Each routine runs at most once a day, and one missed while the Mac was
asleep still runs if the Mac wakes within two hours.

## Calendar

Turn on **Settings → Day → Use Calendar and Reminders** and macOS asks for
access once. The cat then knows today's remaining events and the reminders
due today when you chat (so a morning briefing routine can mention them), and
says so about ten minutes before an event starts. Only titles and times are
read: no notes, attendees or locations. Titles are passed to the AI as data,
not instructions. The heads-up waits while a meeting or presentation is on
screen. Turn the toggle off to stop it.

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
approval. Copy a snippet from Settings > Advanced > Agent notifications:

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
