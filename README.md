# openNeko

[한국어](README.ko.md) · [日本語](README.ja.md) · [简体中文](README.zh.md)

openNeko is an open-source desktop pixel cat for AI agents. It lives along the bottom of your screen, reacts to typing and agent state signals, and answers short chat messages through your chosen agent, cloud model, or local model.

## Features

- **AI Agent chat**: short-click the cat, type a message, and get a compact cat-style reply.
- **OAuth-first providers**: OpenAI/Codex, Claude, and Gemini CLI logins first; API keys only when needed.
- **Local models**: Ollama and local OpenAI-compatible servers can answer without a cloud API key.
- **Agent status bridge**: reacts to HTTP state events and busy agent processes including Cursor, Claude Code CLI, Codex CLI/App, Antigravity, Gemini, and Kiro.
- **Typing reaction**: the cat animates when you type. Key contents are never read.
- **Skins and sprites**: five bundled skins, external skin folder support, and reusable sprite extraction tools.
- **Skills**: bundled and user `SKILL.md` prompts can be triggered from the menu or slash commands.
- **Neighbor cats**: discover other openNeko instances on the same LAN and show friendly guest cats.

## Install

macOS:

```bash
curl -fsSL https://raw.githubusercontent.com/kimtoma/openNeko/refs/heads/main/scripts/install.sh | bash
```

Windows PowerShell:

```powershell
irm https://raw.githubusercontent.com/kimtoma/openNeko/refs/heads/main/scripts/install.ps1 | iex
```

Both installers need `git` and Node.js `22.12+`. To skip login autostart, set `OPENNEKO_NO_AUTOSTART=1` before running the installer.

## Run From Source

```bash
git clone https://github.com/kimtoma/openNeko.git
cd openNeko
npm install
npm run build
npm start
```

For keyless setup, sign in with a supported CLI first: `codex login`, `claude`, or `gemini`. Ollama and local OpenAI-compatible endpoints can be added in Settings.

## AI Providers

Supported presets:

- `chatgpt-oauth`: uses the local Codex CLI OpenAI login. Requires `codex login`.
- `claude-oauth`: uses the local Claude Code login.
- `gemini-oauth`: uses the local Gemini CLI Google login.
- `ollama`: uses a local Ollama server.
- `local-openai`: local OpenAI-compatible servers such as LM Studio, llama.cpp, or vLLM.
- `gemini`: Google AI Studio Gemini API key.
- `claude`: Anthropic API key.
- `custom`: any OpenAI-compatible endpoint, with an API key only if that server requires one.

API keys are stored with Electron `safeStorage` when available.

## State Bridge

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

Bundled skills live in `src/skills/builtin/*/SKILL.md`. User skills go in:

```text
~/.openneko/skills/<skill-id>/SKILL.md
```

Supported skill inputs are `prompt`, `clipboard`, and `none`. Skill bodies are injected as system instructions for the current AI provider; scripts are not executed.

## Development

```bash
npm test
npm run build
```

Electron loads bundled renderer files, so run `npm run build` after changing `src/renderer/cat2d.js` or `src/settings/settings.js`.

## License

MIT
