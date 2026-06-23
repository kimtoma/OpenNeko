const { OpenAICompatProvider } = require('./openaiCompat');
const { CodexCliProvider } = require('./codexCli');
const { ClaudeCliProvider, GeminiCliProvider } = require('./agentCli');
const { GeminiProvider } = require('./gemini');
const { AnthropicProvider } = require('./anthropic');

const DEFAULT_BASE_URL = 'https://api.openai.com/v1';
const DEFAULT_MODEL = 'gpt-4o-mini';

// config: { type, model?, baseURL?, apiKey?, lang? }
function createProvider(config) {
  const c = config || { type: 'codex-cli' };
  const lang = c.lang || 'en';
  switch (c.type || 'codex-cli') {
    case 'openai-compat':
      return new OpenAICompatProvider({
        baseURL: c.baseURL || DEFAULT_BASE_URL,
        apiKey: c.apiKey,
        model: c.model || DEFAULT_MODEL,
        lang,
      });
    case 'codex-cli':
      return new CodexCliProvider({
        bin: c.bin || c.cliBin || 'codex',
        model: c.model || '',
        lang,
      });
    case 'claude-cli':
      return new ClaudeCliProvider({
        bin: c.bin || c.cliBin || 'claude',
        model: c.model || '',
        lang,
      });
    case 'gemini-cli':
      return new GeminiCliProvider({
        bin: c.bin || c.cliBin || 'gemini',
        model: c.model || '',
        lang,
      });
    case 'gemini':
      return new GeminiProvider({
        apiKey: c.apiKey,
        model: c.model,
        baseURL: c.baseURL,
        lang,
      });
    case 'anthropic':
      return new AnthropicProvider({
        apiKey: c.apiKey,
        model: c.model,
        baseURL: c.baseURL,
        lang,
      });
    default:
      throw new Error(`알 수 없는 LLM provider type: ${c.type}`);
  }
}
module.exports = { createProvider, DEFAULT_BASE_URL, DEFAULT_MODEL };
