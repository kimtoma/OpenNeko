// Settings UI presets. Keep the public openNeko build GPT-first and
// OpenAI-compatible, so local providers can work without a separate adapter.
const PRESETS = [
  {
    id: 'openai',
    label: 'OpenAI GPT',
    type: 'openai-compat',
    envKey: 'OPENAI_API_KEY',
    defaults: { baseURL: 'https://api.openai.com/v1', model: 'gpt-4o-mini' },
    fields: ['apiKey', 'model'],
  },
  {
    id: 'ollama',
    label: 'Ollama (local)',
    type: 'openai-compat',
    local: 'http://localhost:11434',
    defaults: { baseURL: 'http://localhost:11434/v1', model: 'llama3.2' },
    fields: ['baseURL', 'model'],
  },
  {
    id: 'custom',
    label: 'Custom OpenAI-compatible',
    type: 'openai-compat',
    defaults: { baseURL: '', model: '' },
    fields: ['baseURL', 'apiKey', 'model'],
  },
];

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
  return savedKey;
}

module.exports = { PRESETS, presetConfig, resolveApiKey };
