const { test } = require('node:test');
const assert = require('node:assert');
const {
  AnthropicProvider,
  anthropicMessages,
  textFromAnthropicEvent,
  ANTHROPIC_VERSION,
} = require('../src/llm/anthropic');

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

test('anthropicMessages: role/content 메시지 배열로 변환', () => {
  assert.deepEqual(anthropicMessages([
    { role: 'user', text: 'hi' },
    { role: 'assistant', text: 'hello' },
  ]), [
    { role: 'user', content: 'hi' },
    { role: 'assistant', content: 'hello' },
  ]);
});

test('textFromAnthropicEvent: text_delta만 추출', () => {
  assert.equal(textFromAnthropicEvent({
    type: 'content_block_delta',
    delta: { type: 'text_delta', text: 'Hello' },
  }), 'Hello');
  assert.equal(textFromAnthropicEvent({ type: 'ping' }), '');
});

test('AnthropicProvider.chat: messages 요청과 SSE text_delta 처리', async () => {
  const p = new AnthropicProvider({ apiKey: 'a-key', model: 'claude-test', lang: 'ko' });
  let capturedUrl = '';
  let capturedHeaders = null;
  let capturedBody = null;
  p._fetch = async (url, opts) => {
    capturedUrl = url;
    capturedHeaders = opts.headers;
    capturedBody = JSON.parse(opts.body);
    return fakeSSE([
      'event: content_block_delta\n',
      'data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"안"}}\n\n',
      'event: content_block_delta\n',
      'data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"녕"}}\n\n',
    ]);
  };
  const deltas = [];
  const r = await p.chat({
    history: [{ role: 'user', text: '테스트' }],
    system: 'custom-system',
    onDelta: (d) => deltas.push(d),
  });
  assert.equal(capturedUrl, 'https://api.anthropic.com/v1/messages');
  assert.equal(capturedHeaders['x-api-key'], 'a-key');
  assert.equal(capturedHeaders['anthropic-version'], ANTHROPIC_VERSION);
  assert.equal(capturedBody.model, 'claude-test');
  assert.equal(capturedBody.system, 'custom-system');
  assert.equal(capturedBody.stream, true);
  assert.equal(r.text, '안녕');
  assert.deepEqual(deltas, ['안', '녕']);
});

test('AnthropicProvider.chat: API key 없으면 AUTH', async () => {
  const p = new AnthropicProvider({ apiKey: '' });
  await assert.rejects(p.chat({ history: [{ role: 'user', text: 'x' }] }), (e) => e.code === 'AUTH');
});
