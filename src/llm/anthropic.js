const { historyToMessages, persona, httpError, makeAbort } = require('./format');
const { createSSEParser } = require('./sse');

const TIMEOUT_MS = 30000;
const DEFAULT_BASE_URL = 'https://api.anthropic.com/v1';
const DEFAULT_MODEL = 'claude-opus-4-8';
const ANTHROPIC_VERSION = '2023-06-01';

function anthropicMessages(history) {
  return historyToMessages(history).map((m) => ({
    role: m.role === 'assistant' ? 'assistant' : 'user',
    content: m.content,
  }));
}

function textFromAnthropicEvent(o) {
  if (!o || o.type !== 'content_block_delta') return '';
  const delta = o.delta || {};
  return delta.type === 'text_delta' && delta.text ? delta.text : '';
}

class AnthropicProvider {
  constructor({ apiKey, model, baseURL, lang, maxTokens } = {}) {
    this.name = 'anthropic';
    this.apiKey = apiKey || '';
    this.model = model || DEFAULT_MODEL;
    this.baseURL = String(baseURL || DEFAULT_BASE_URL).replace(/\/+$/, '');
    this.lang = lang || 'en';
    this.maxTokens = maxTokens || 1024;
    this._fetch = (...a) => fetch(...a);
  }

  async chat({ history, signal, onDelta, system }) {
    if (!this.apiKey) throw Object.assign(new Error('Anthropic API key required'), { code: 'AUTH' });
    const sys = (system !== undefined && system !== null) ? system : persona(this.lang);
    const body = {
      model: this.model,
      max_tokens: this.maxTokens,
      system: sys,
      messages: anthropicMessages(history),
      stream: true,
    };
    const ab = makeAbort(signal, TIMEOUT_MS);
    let res;
    try {
      res = await this._fetch(`${this.baseURL}/messages`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': this.apiKey,
          'anthropic-version': ANTHROPIC_VERSION,
        },
        signal: ab.signal,
        body: JSON.stringify(body),
      });
    } catch (e) { throw ab.rethrow(e); }
    if (!res.ok) { ab.clear(); throw httpError(res.status, await res.text().catch(() => '')); }
    if (!res.body) { ab.clear(); throw new Error('빈 응답'); }

    const feed = createSSEParser();
    const dec = new TextDecoder();
    const reader = res.body.getReader();
    let acc = '';
    try {
      for (;;) {
        const { done, value } = await reader.read();
        if (done) break;
        for (const d of feed(typeof value === 'string' ? value : dec.decode(value, { stream: true }))) {
          let o; try { o = JSON.parse(d); } catch { continue; }
          if (o && o.type === 'error') {
            const msg = o.error && o.error.message ? o.error.message : 'Anthropic stream error';
            throw Object.assign(new Error(msg), { code: 'HTTP' });
          }
          const chunk = textFromAnthropicEvent(o);
          if (chunk) { acc += chunk; if (onDelta) onDelta(chunk); }
        }
      }
    } catch (e) { throw ab.rethrow(e); } finally { ab.clear(); }
    const text = acc.trim();
    if (!text) throw new Error('빈 응답');
    return { text };
  }
}

module.exports = { AnthropicProvider, anthropicMessages, textFromAnthropicEvent, ANTHROPIC_VERSION };
