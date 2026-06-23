// Settings card categorization. Pure logic, covered by node:test.

const FRIENDLY_LABELS = {
  'chatgpt-oauth': 'OpenAI Login',
  'claude-oauth': 'Claude Login',
  'gemini-oauth': 'Gemini Login',
  ollama: 'Ollama',
  'local-openai': 'Local endpoint',
  gemini: 'Gemini API Key',
  claude: 'Claude API Key',
  custom: 'Custom endpoint',
};

function friendlyLabel(presetId, fallback, t) {
  if (t) {
    const key = 'provider.' + presetId;
    const translated = t(key);
    if (translated !== key) return translated;
  }
  return FRIENDLY_LABELS[presetId] || fallback || presetId;
}

// Returns: { ready: [...click-to-apply cards], connect: [...form cards], currentId }
// - detected env/local providers are ready cards.
// - providers that need key/baseURL input remain in connect unless already ready.
function categorizeProviders({ presets = [], detected = [], currentPresetId = 'chatgpt-oauth' } = {}) {
  const byId = Object.fromEntries(presets.map((p) => [p.id, p]));
  const ready = [];
  const seen = new Set();

  for (const d of detected) {
    if (seen.has(d.presetId) || !byId[d.presetId]) continue;
    const models = d.models && d.models.length ? ` · ${d.models.slice(0, 2).join(', ')}` : '';
    ready.push({
      presetId: d.presetId,
      label: friendlyLabel(d.presetId, byId[d.presetId].label),
      subtitle: `Ready${models}`,
      source: d.source,
      models: d.models || [],
      recommended: !!byId[d.presetId].recommended,
    });
    seen.add(d.presetId);
  }

  const connect = [];
  for (const p of presets) {
    if (seen.has(p.id)) continue;
    const fields = p.fields || [];
    const needsInput = fields.includes('apiKey') || fields.includes('baseURL');
    if (needsInput || p.cliBin) connect.push({ presetId: p.id, label: friendlyLabel(p.id, p.label), fields });
  }

  return { ready, connect, currentId: currentPresetId };
}

module.exports = { categorizeProviders, friendlyLabel, FRIENDLY_LABELS };
