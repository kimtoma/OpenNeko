# openNeko

openNeko is an open-source desktop pixel cat for GPT. It is an Electron app
that lives in a transparent desktop window, reacts to typing and state bridge
events, and chats through OpenAI-compatible `/v1/chat/completions` providers
or the local Codex CLI ChatGPT OAuth session.

## Commands

```bash
npm start          # build bundles, then launch Electron
npm run build      # bundle renderer and settings window
npm test           # node:test suite
```

Electron loads bundled files:

- `src/renderer/cat2d.bundle.js`
- `src/settings/settings.bundle.js`

Run `npm run build` after changing `src/renderer/cat2d.js` or
`src/settings/settings.js`.

## LLM Design

- Default preset: `chatgpt-oauth`
- Default model: selected by the local Codex CLI unless the user enters one
- Provider implementations: `src/llm/openaiCompat.js`, `src/llm/codexCli.js`,
  `src/llm/gemini.js`, `src/llm/anthropic.js`
- Presets: `chatgpt-oauth`, `gemini`, `claude`, `custom`
- `chatgpt-oauth` uses `codex exec` and requires `codex login`; do not read
  or parse `~/.codex/auth.json` directly.
- Saved API keys use Electron `safeStorage` through `src/settings.js`.
- Skill/profile/persona context is composed in `src/main.js` and sent as the
  system message for chat and skill calls.

Do not add vendor-specific hook installers or provider modules unless the
project explicitly chooses to broaden the public provider surface.

## Skills

- Bundled skills: `src/skills/builtin/*/SKILL.md`
- User skills: `~/.openneko/skills/*/SKILL.md`
- Skill bodies are prompt instructions only. Scripts are not executed.

## State Bridge

HTTP:

```bash
POST http://127.0.0.1:48800/state
{"state":"coding","source":"agent","message":"optional"}
```

Debug endpoints:

- `GET /health`
- `GET /anim`
- `GET /capture`

Use `OPENNEKO_PORT=48801` for a second local instance.

## Resources

Keep reusable visual resources unless a task explicitly replaces them:

- `src/renderer/sprites/`
- `assets/gen/`
- `tools/extract_gen.py`
- `tools/extract_sprites.py`

The sprite pipeline expects 2x2 source grids and transparent extracted frames.

## Conventions

- Keep UI copy short; the cat speech bubble is small.
- Preserve the "clicks pass through outside the cat" behavior.
- Do not read key contents. Typing reactions use keydown events only.
- Keep unrelated local changes out of scope.
