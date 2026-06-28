# openNeko Progress

## Current Scope

openNeko is a clean open-source desktop pet built around GPT and
OpenAI-compatible chat completions.

Included:

- Electron transparent bottom-strip pet window
- Pixel sprite renderer and five bundled skins
- OpenAI-compatible GPT chat provider
- OpenAI, Ollama, and custom endpoint presets
- Settings window, encrypted API key storage, profile fields, language support
- Prompt-only skill system and slash commands
- HTTP state bridge, keyboard reaction, and LAN neighbor cats
- macOS and Windows install scripts

Removed from the clean public baseline:

- vendor-specific hook installers
- old development session exports
- old private-project planning logs
- removed provider modules and their tests

## Validation

Run before release or PR handoff:

```bash
npm test
npm run build
rg -n "removed-vendor-string|old-project-name" .
```

The text scan should be adapted to the exact migration or cleanup task.

## Notes

- User skills live under `~/.openneko/skills/`.
- External skins live under the app user-data `skins/<id>/` directory.
- `OPENNEKO_PORT` can run multiple local instances for LAN testing.
- `OPENAI_API_KEY` is the default key fallback for GPT chat.
