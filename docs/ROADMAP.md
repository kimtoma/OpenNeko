# OpenNeko roadmap

Direction (see "Product direction" in `AGENTS.md`): power users first,
macOS first, and the cat as the face and approval desk for the AI agents the
user already runs. Estimates assume one part-time maintainer and are rough.

## Now

| Item | Goal | Notes |
| --- | --- | --- |
| Agent notification bridge | The cat tells you when Claude Code / Codex finished or needs approval | Hooks call `POST /state`; new `waiting` state; copy-paste snippets first (see "Agent hooks" in AGENTS.md). ~1–2 weeks |
| Free mode v1 (local model setup) | Users without a paid subscription get a working cat in one flow | Hardware detection → model recommendation (pure function + JSON catalog in OpenNekoKit) → consented Ollama install → `/api/pull` with progress → existing Ollama preset. ~2–3 weeks |
| Korean local-model evaluation | Pick the catalog defaults per memory tier | 20 persona prompts + 4 tool-calling cases, run through Ollama |
| Health companion | Break / stretch nudges from typing activity (timestamps only) | No LLM needed. Frequency caps and an "enough for today" switch |

## Next

| Item | Goal | Notes |
| --- | --- | --- |
| Task delegation + approval bubble (A1) | Hand a folder-scoped task to an installed CLI agent; the cat shows `working`, asks in the bubble, reports the result | Tools enabled only inside the chosen folder; activity log |
| Native tools (A2) | Timer, reminder, calendar read, clipboard, open URL | Tool schemas and approval policy in OpenNekoKit; MCP for user-added tools |
| Selected text → cat | Hotkey or Services menu to translate / explain / summarize a selection | No screen capture |
| Apple Foundation Models preset | Zero-download model on macOS 26+ Apple Intelligence Macs | Runtime availability check; macOS 14 stays supported |

## Later

- Routines (scheduled tasks such as a morning briefing)
- Push-to-talk voice input with on-device speech recognition
- Relationship and growth (opt-in memory, unlockable expressions), together
  with the sprite redesign
- Embedding llama.cpp instead of depending on Ollama (free mode v2)
- Windows parity for the features above, after the Windows port is merged

## Not planned

Phone calls, purchases or bookings on the user's behalf, a hosted cloud
agent, driving arbitrary app UIs, a mobile app.
