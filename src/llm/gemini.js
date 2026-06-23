const { historyToMessages, persona, httpError, makeAbort } = require('./format');
const { createSSEParser } = require('./sse');

const TIMEOUT_MS = 30000;
const DEFAULT_BASE_URL = 'https://generativelanguage.googleapis.com/v1beta';
const DEFAULT_MODEL = 'gemini-3.5-flash';

function modelPath(model) {
  const m = String(model || DEFAULT_MODEL).replace(/^\/+/, '');
  return m.startsWith('models/') ? m : `models/${m}`;
}

function geminiContents(history) {
  return historyToMessages(history).map((m) => ({
    role: m.role === 'assistant' ? 'model' : 'user',
    parts: [{ text: m.content }],
  }));
}

function textFromGeminiChunk(o) {
  const parts = o && o.candidates && o.candidates[0] &&
    o.candidates[0].content && o.candidates[0].content.parts;
  return Array.isArray(parts) ? parts.map((p) => p && p.text).filter(Boolean).join('') : '';
}

class GeminiProvider {
  constructor({ apiKey, model, baseURL, lang } = {}) {
    this.name = 'gemini';
    this.apiKey = apiKey || '';
    this.model = model || DEFAULT_MODEL;
    this.baseURL = String(baseURL || DEFAULT_BASE_URL).replace(/\/+$/, '');
    this.lang = lang || 'en';
    this._fetch = (...a) => fetch(...a);
  }

  async chat({ history, signal, onDelta, system }) {
    if (!this.apiKey) throw Object.assign(new Error('Gemini API key required'), { code: 'AUTH' });
    const sys = (system !== undefined && system !== null) ? system : persona(this.lang);
    const body = {
      system_instruction: { parts: [{ text: sys }] },
      contents: geminiContents(history),
    };
    const url = `${this.baseURL}/${modelPath(this.model)}:streamGenerateContent?alt=sse&key=${encodeURIComponent(this.apiKey)}`;
    const ab = makeAbort(signal, TIMEOUT_MS);
    let res;
    try {
      res = await this._fetch(url, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
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
          const chunk = textFromGeminiChunk(o);
          if (chunk) { acc += chunk; if (onDelta) onDelta(chunk); }
        }
      }
    } catch (e) { throw ab.rethrow(e); } finally { ab.clear(); }
    const text = acc.trim();
    if (!text) throw new Error('빈 응답');
    return { text };
  }
}

module.exports = { GeminiProvider, geminiContents, modelPath, textFromGeminiChunk };
