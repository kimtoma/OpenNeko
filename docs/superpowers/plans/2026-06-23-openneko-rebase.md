# openNeko Rebase Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create a clean local `openNeko` repo from reusable desktop pet resources, centered on GPT/OpenAI-compatible chat.

**Architecture:** Keep the Electron desktop pet, renderer, sprite, skin, LAN, settings, skill, and update foundations. Replace the legacy multi-vendor LLM surface with a smaller GPT-first provider catalog backed by OpenAI-compatible chat completions.

**Tech Stack:** Electron, Node.js `node:test`, esbuild, OpenAI-compatible streaming chat completions, local Ollama-compatible endpoints.

## Global Constraints

- New repo path: `/Users/macmini/Projects/openNeko`.
- Do not edit tracked files in the source checkout.
- App name, package metadata, install scripts, user-data paths, docs, and tests must use `openNeko`.
- Remove vendor-specific hook installers, session exports, legacy provider modules, and old project development logs.
- Default chat preset must be OpenAI GPT with `OPENAI_API_KEY` support.
- Keep reusable resources: sprites, skins, sound, settings UI, LAN neighbor cats, profile, skills, slash commands, updater logic, and installer scaffolding.

---

### Task 1: Clean Repo Shell

**Files:**
- Modify: `package.json`, `package-lock.json`, `.github/*`, `scripts/*`
- Delete: legacy development logs and provider/hook helper files
- Create: `docs/PROGRESS.md`

**Interfaces:**
- Produces a standalone Git repo that builds with `npm run build` and stores app data under an `openNeko` product name.

- [ ] Remove old development-session docs and hook/session helper tools.
- [ ] Rewrite package metadata, installer variables, issue templates, and progress docs for `openNeko`.
- [ ] Verify no legacy project-name references remain outside intentionally excluded dependency metadata.

### Task 2: GPT-First LLM Layer

**Files:**
- Modify: `src/llm/index.js`, `src/llm/presets.js`, `src/llm/detect.js`, `src/settings/cards.js`, `src/settings/settings.js`, `src/main.js`, `src/i18n/index.js`
- Delete: removed provider modules' tests
- Test: `test/llm.test.js`, `test/detect.test.js`, `test/settings-cards.test.js`, `test/settings.test.js`, `test/i18n.test.js`

**Interfaces:**
- `createProvider(config?)` defaults to `OpenAICompatProvider`.
- `PRESETS` contains `openai`, `ollama`, and `custom`.
- `settings-get` defaults to `presetId: "openai"`.

- [ ] Remove imports and branches for removed provider modules.
- [ ] Make the default provider `{ type: "openai-compat", preset: "openai", baseURL: "https://api.openai.com/v1", model: "gpt-4o-mini" }`.
- [ ] Update provider detection to use `OPENAI_API_KEY` and local Ollama only.
- [ ] Update settings cards and translated labels so OpenAI GPT is recommended.
- [ ] Update tests to assert GPT-first defaults and provider catalog.

### Task 3: Public-Facing Docs

**Files:**
- Modify: `README.md`, `README.ko.md`, `README.ja.md`, `README.zh.md`, `AGENTS.md`, `CONTRIBUTING.md`

**Interfaces:**
- Produces concise public docs for installing, running, configuring GPT, adding skills, and using the HTTP state bridge.

- [ ] Rewrite all READMEs around `openNeko`.
- [ ] Replace legacy project context with an `openNeko` AGENTS guide.
- [ ] Keep install/run/test commands accurate.

### Task 4: Verify And Save

**Files:**
- Generated: `src/renderer/cat2d.bundle.js`, `src/settings/settings.bundle.js`
- Git: initial local commit

**Interfaces:**
- Produces a committed local repository at `/Users/macmini/Projects/openNeko`.

- [ ] Run `npm install --package-lock-only` if package metadata changed.
- [ ] Run `npm test --silent`.
- [ ] Run `npm run build --silent`.
- [ ] Run a repo text scan for removed legacy/vendor traces.
- [ ] Commit the clean initial `openNeko` repo locally.
