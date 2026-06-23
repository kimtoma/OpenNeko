const { OpenAICompatProvider } = require('./openaiCompat');

const DEFAULT_BASE_URL = 'https://api.openai.com/v1';
const DEFAULT_MODEL = 'gpt-4o-mini';

// config: { type, model?, baseURL?, apiKey?, lang? }
function createProvider(config) {
  const c = config || {};
  const model = c.model || DEFAULT_MODEL;
  const lang = c.lang || 'en';
  switch (c.type || 'openai-compat') {
    case 'openai-compat':
      return new OpenAICompatProvider({
        baseURL: c.baseURL || DEFAULT_BASE_URL,
        apiKey: c.apiKey,
        model,
        lang,
      });
    default:
      throw new Error(`알 수 없는 LLM provider type: ${c.type}`);
  }
}
module.exports = { createProvider, DEFAULT_BASE_URL, DEFAULT_MODEL };
