// Settings UI presets. Prefer logged-in agent CLIs and local models before API keys.
const PRESETS = [
  {
    id: 'chatgpt-oauth',
    label: 'OpenAI Login (Codex)',
    type: 'codex-cli',
    cliBin: 'codex',
    auth: 'oauth',
    defaults: { model: '' },
    fields: ['model'],
    note: 'Uses your local Codex login. Run `codex login` first.',
    recommended: true,
  },
  {
    id: 'claude-oauth',
    label: 'Claude Login',
    type: 'claude-cli',
    cliBin: 'claude',
    auth: 'oauth',
    defaults: { model: '' },
    fields: ['model'],
    note: 'Uses your local Claude Code login. Run `claude` and sign in first.',
  },
  {
    id: 'gemini-oauth',
    label: 'Gemini Login',
    type: 'gemini-cli',
    cliBin: 'gemini',
    auth: 'oauth',
    defaults: { model: '' },
    fields: ['model'],
    note: 'Uses your local Gemini CLI Google login. Run `gemini` and choose Login with Google first.',
  },
  {
    id: 'ollama',
    label: 'Ollama',
    type: 'openai-compat',
    local: true,
    defaults: { baseURL: 'http://localhost:11434/v1', model: '' },
    fields: ['baseURL', 'model'],
    note: 'Uses a local Ollama server. Start Ollama and pull a model first.',
  },
  {
    id: 'local-openai',
    label: 'Local OpenAI-compatible',
    type: 'openai-compat',
    local: true,
    defaults: { baseURL: 'http://localhost:1234/v1', model: '' },
    fields: ['baseURL', 'model'],
    note: 'Use LM Studio, llama.cpp, vLLM, or another local OpenAI-compatible server.',
  },
  {
    id: 'gemini',
    label: 'Gemini API Key',
    type: 'gemini',
    envKey: 'GEMINI_API_KEY',
    envKeyAlt: 'GOOGLE_API_KEY',
    requiresApiKey: true,
    defaults: { model: 'gemini-3.5-flash' },
    fields: ['apiKey', 'model'],
    note: 'Uses a Google AI Studio Gemini API key.',
  },
  {
    id: 'claude',
    label: 'Claude API Key',
    type: 'anthropic',
    envKey: 'ANTHROPIC_API_KEY',
    requiresApiKey: true,
    defaults: { baseURL: 'https://api.anthropic.com/v1', model: 'claude-opus-4-8' },
    fields: ['apiKey', 'model'],
    note: 'Uses an Anthropic API key.',
  },
  {
    id: 'custom',
    label: 'Custom OpenAI-compatible',
    type: 'openai-compat',
    defaults: { baseURL: '', model: '' },
    fields: ['baseURL', 'apiKey', 'model'],
    requiresApiKey: false,
  },
];

const DEFAULT_PRESET_ID = PRESETS[0].id;

function presetConfig(id, overrides = {}) {
  const p = PRESETS.find((x) => x.id === id) || PRESETS[0];
  return { preset: p.id, type: p.type, ...p.defaults, ...overrides };
}

// Stored keys win over env vars, so an explicit user choice is stable.
function resolveApiKey(presetId, savedKey, env = process.env) {
  if (savedKey) return savedKey;
  const p = PRESETS.find((x) => x.id === presetId);
  if (!p) return savedKey;
  if (p.envKey && env[p.envKey]) return env[p.envKey];
  if (p.envKeyAlt && env[p.envKeyAlt]) return env[p.envKeyAlt];
  return savedKey;
}

module.exports = { PRESETS, DEFAULT_PRESET_ID, presetConfig, resolveApiKey };
