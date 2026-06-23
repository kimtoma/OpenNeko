const { test } = require('node:test');
const assert = require('node:assert');
const { GeminiProvider, geminiContents, modelPath, textFromGeminiChunk } = require('../src/llm/gemini');

function fakeSSE(lines) {
  const enc = new TextEncoder();
  return {
    ok: true,
    status: 200,
    body: {
      getReader() {
        let i = 0;
        return {
          read() {
            if (i >= lines.length) return Promise.resolve({ done: true });
            return Promise.resolve({ done: false, value: enc.encode(lines[i++]) });
          },
        };
      },
    },
  };
}

test('modelPath: models/ prefix를 한 번만 붙임', () => {
  assert.equal(modelPath('gemini-3.5-flash'), 'models/gemini-3.5-flash');
  assert.equal(modelPath('models/gemini-3.5-flash'), 'models/gemini-3.5-flash');
});

test('geminiContents: assistant role은 model로 변환', () => {
  assert.deepEqual(geminiContents([
    { role: 'user', text: 'hi' },
    { role: 'assistant', text: 'hello' },
  ]), [
    { role: 'user', parts: [{ text: 'hi' }] },
    { role: 'model', parts: [{ text: 'hello' }] },
  ]);
});

test('textFromGeminiChunk: candidates content parts text 누적용 추출', () => {
  const text = textFromGeminiChunk({ candidates: [{ content: { parts: [{ text: '안' }, { text: '녕' }] } }] });
  assert.equal(text, '안녕');
});

test('GeminiProvider.chat: streamGenerateContent 요청과 SSE delta 처리', async () => {
  const p = new GeminiProvider({ apiKey: 'g-key', model: 'gemini-test', lang: 'ko' });
  let capturedUrl = '';
  let capturedBody = null;
  p._fetch = async (url, opts) => {
    capturedUrl = url;
    capturedBody = JSON.parse(opts.body);
    return fakeSSE([
      'data: {"candidates":[{"content":{"parts":[{"text":"안"}]}}]}\n\n',
      'data: {"candidates":[{"content":{"parts":[{"text":"녕"}]}}]}\n\n',
    ]);
  };
  const deltas = [];
  const r = await p.chat({
    history: [{ role: 'user', text: '테스트' }],
    system: 'custom-system',
    onDelta: (d) => deltas.push(d),
  });
  assert.match(capturedUrl, /models\/gemini-test:streamGenerateContent\?alt=sse&key=g-key/);
  assert.equal(capturedBody.system_instruction.parts[0].text, 'custom-system');
  assert.equal(capturedBody.contents[0].role, 'user');
  assert.equal(r.text, '안녕');
  assert.deepEqual(deltas, ['안', '녕']);
});

test('GeminiProvider.chat: API key 없으면 AUTH', async () => {
  const p = new GeminiProvider({ apiKey: '' });
  await assert.rejects(p.chat({ history: [{ role: 'user', text: 'x' }] }), (e) => e.code === 'AUTH');
});
