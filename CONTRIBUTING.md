# Contributing to openNeko

Thanks for helping with openNeko. Bug reports, feature ideas, code changes,
translations, skins, and docs improvements are welcome.

## Local Setup

```bash
git clone https://github.com/kimtoma/openNeko.git
cd openNeko
npm install
npm test
npm run build
```

Use Node.js `22.12+`.

## Pull Requests

- Keep changes focused.
- Run `npm test` and `npm run build` before opening a PR.
- Do not commit generated local settings, API keys, or `node_modules`.
- If you change renderer or settings source files, include the regenerated
  bundle output or make it clear that maintainers should rebuild before release.

## GPT Providers

The public provider surface is intentionally small:

- OpenAI GPT
- local Ollama through its OpenAI-compatible endpoint
- custom OpenAI-compatible endpoint

Please discuss broader provider additions before opening a large PR.

## Skills

User skills live in:

```text
~/.openneko/skills/<skill-id>/SKILL.md
```

Skill bodies are prompt instructions. openNeko does not execute scripts from
skill folders.

## Skins

External skins can be tested locally under:

```text
~/Library/Application Support/openNeko/skins/<id>/
```

Each skin should include state frame PNGs matching the bundled sprite naming
scheme. Reuse `tools/extract_gen.py` when generating frames from source grids.

## Security

Never include secrets in issues, logs, screenshots, or test fixtures. API keys
are stored through Electron `safeStorage` when available.
