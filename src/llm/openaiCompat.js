const { historyToMessages, persona, httpError, makeAbort } = require('./format');
const { createSSEParser } = require('./sse');

const TIMEOUT_MS = 30000;

class OpenAICompatProvider {
  constructor({ baseURL, apiKey, model, lang }) {
    this.name = 'openai-compat';
    this.baseURL = String(baseURL || '').replace(/\/+$/, '');
    this.apiKey = apiKey || '';
    this.model = model;
    this.lang = lang || 'en';
    this._fetch = (...a) => fetch(...a);
  }

  // system: 옵셔널 — 있으면 persona(lang) 대신 이 값을 시스템 프롬프트로 사용.
  async chat({ history, signal, onDelta, system }) {
    const sys = (system !== undefined && system !== null) ? system : persona(this.lang);
    const messages = [{ role: 'system', content: sys }, ...historyToMessages(history)];
    const headers = { 'Content-Type': 'application/json' };
    if (this.apiKey) headers.Authorization = `Bearer ${this.apiKey}`;
    const ab = makeAbort(signal, TIMEOUT_MS);
    let res;
    try {
      res = await this._fetch(`${this.baseURL}/chat/completions`, {
        method: 'POST', headers, signal: ab.signal,
        body: JSON.stringify({ model: this.model, messages, stream: true }),
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
          if (d === '[DONE]') continue;
          let o; try { o = JSON.parse(d); } catch { continue; }
          const c = o.choices && o.choices[0] && o.choices[0].delta && o.choices[0].delta.content;
          if (c) { acc += c; if (onDelta) onDelta(c); }
        }
      }
    } catch (e) { throw ab.rethrow(e); } finally { ab.clear(); }
    const text = acc.trim();
    if (!text) throw new Error('빈 응답');
    return { text };
  }
}
module.exports = { OpenAICompatProvider };
