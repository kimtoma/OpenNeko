<p align="center">
  <img src="docs/assets/sprites/black/jump_0.png" width="112" alt="openNeko pixel cat">
</p>

<h1 align="center">openNeko</h1>

<p align="center">
  A tiny open-source desktop pixel cat that talks to your AI agents, reacts to typing, and mirrors agent activity without interrupting your workflow.
</p>

<p align="center">
  <a href="README.ko.md">한국어</a> ·
  <a href="README.ja.md">日本語</a> ·
  <a href="README.zh.md">简体中文</a>
</p>

<p align="center">
  <img alt="license MIT" src="https://shieldcn.dev/badge/license-MIT-111318.svg?variant=outline&size=sm">
  <img alt="runtime Electron" src="https://shieldcn.dev/badge/runtime-Electron-00a8c8.svg?variant=secondary&size=sm&logo=electron">
  <img alt="node 22.12+" src="https://shieldcn.dev/badge/node-%E2%89%A522.12-43b97f.svg?variant=secondary&size=sm&logo=nodedotjs">
  <img alt="AI OAuth first" src="https://shieldcn.dev/badge/AI-OAuth%20first-ffd866.svg?variant=secondary&size=sm">
  <img alt="tests 177 passing" src="https://shieldcn.dev/badge/tests-177%20passing-43b97f.svg?variant=outline&size=sm">
</p>

<p align="center">
  <a href="https://github.com/kimtoma/openNeko">GitHub</a> ·
  <a href="https://kimtoma.github.io/openNeko/">Project page</a> ·
  <a href="https://github.com/kimtoma/openNeko/issues">Issues</a>
</p>

---

## What is openNeko?

openNeko is a local-first desktop companion for people working with AI agents. It lives along the bottom of your screen, walks around the macOS Dock area, reacts to global typing events without reading key contents, and changes motion based on agent state signals.

It can also answer short messages through ChatGPT/Codex, Claude, Gemini, Ollama, or any OpenAI-compatible endpoint you configure.

## Highlights

| Area | What it does |
| --- | --- |
| **Agent chat** | Short-click the cat, type a message, and get a compact cat-style reply. |
| **OAuth-first setup** | Uses ChatGPT/Codex, Claude, and Gemini CLI login sessions before asking for API keys. |
| **Local models** | Connect Ollama or a local OpenAI-compatible server without cloud credentials. |
| **State bridge** | Reacts to HTTP state events and active agents such as Cursor, Claude Code CLI, Codex CLI/App, Antigravity, Gemini, and Kiro. |
| **Typing reaction** | Animates while you type; key contents are never read. |
| **Skills** | Run bundled or user `SKILL.md` prompts from the menu or slash commands. |
| **Skins** | Ships with five free skins and supports external skin folders. |
| **Neighbor cats** | Discovers other openNeko instances on the same LAN and shows friendly guest cats. |

## Quick Install

macOS:

```bash
curl -fsSL https://raw.githubusercontent.com/kimtoma/openNeko/refs/heads/main/scripts/install.sh | bash
```

Windows PowerShell:

```powershell
irm https://raw.githubusercontent.com/kimtoma/openNeko/refs/heads/main/scripts/install.ps1 | iex
```

Both installers need `git` and Node.js `22.12+`. To skip login autostart, set `OPENNEKO_NO_AUTOSTART=1` before running the installer. The onboarding wizard also includes a **Launch when computer starts** toggle, and the same option is available later in Settings.

For app-style distribution, build native installers:

```bash
npm run dist      # macOS DMG
npm run dist:win  # Windows NSIS installer
```

## Run From Source

```bash
git clone https://github.com/kimtoma/openNeko.git
cd openNeko
npm install
npm run build
npm start
```

Electron loads bundled renderer files, so run `npm run build` after changing `src/renderer/cat2d.js` or `src/settings/settings.js`.

## AI Providers

| Preset | Auth mode | Notes |
| --- | --- | --- |
| `chatgpt-oauth` | Codex CLI login | Uses the local ChatGPT/OpenAI login session. Requires `codex login`. |
| `claude-oauth` | Claude Code CLI login | Uses the local Claude Code OAuth session. |
| `gemini-oauth` | Gemini CLI login | Uses the local Gemini OAuth session. |
| `ollama` | Local server | Talks to a local Ollama server. |
| `local-openai` | Local endpoint | Works with LM Studio, llama.cpp, vLLM, or similar OpenAI-compatible servers. |
| `gemini` | API key | Google AI Studio Gemini API key. |
| `claude` | API key | Anthropic API key. |
| `custom` | Optional API key | Any OpenAI-compatible endpoint. |

API keys are stored with Electron `safeStorage` when available.

## State Bridge

Send state updates from tools, scripts, or AI agent hooks:

```bash
curl -X POST http://127.0.0.1:48800/state \
  -H 'Content-Type: application/json' \
  -d '{"state":"coding","source":"agent","message":"Building"}'
```

Debug endpoints:

- `GET /health`
- `GET /anim`
- `GET /capture`

Use `OPENNEKO_PORT=48801` to run a second instance.

## Skills

Bundled skills live in:

```text
src/skills/builtin/*/SKILL.md
```

User skills go in:

```text
~/.openneko/skills/<skill-id>/SKILL.md
```

Supported skill inputs are `prompt`, `clipboard`, and `none`. Skill bodies are injected as system instructions for the current AI provider; scripts are not executed.

Examples:

- `/translate 안녕하세요`
- `/clipboard-summary`
- `/daily-bgm focus`

## Development

```bash
npm test
npm run build
```

The test suite uses Node's built-in test runner and covers provider routing, settings storage, skill parsing, state logic, and desktop behavior helpers.

## Project Layout

```text
src/main.js                 Electron main process, windows, menus, bridge server
src/renderer/cat2d.js       Cat animation and chat UI source
src/settings/               Settings window UI
src/llm/                    Provider adapters and detection
src/skills/builtin/         Built-in skill prompts
docs/                       GitHub Pages landing page
tools/                      Sprite extraction and helper scripts
```

## License

MIT. See [LICENSE](LICENSE).
