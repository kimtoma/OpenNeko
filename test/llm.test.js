const { test } = require('node:test');
const assert = require('node:assert');
const { createProvider, DEFAULT_BASE_URL, DEFAULT_MODEL } = require('../src/llm');
const { PERSONA, persona } = require('../src/llm/persona');
const { formatPrompt, historyToMessages, httpError, makeAbort, redactSecrets } = require('../src/llm/format');
const { createSSEParser } = require('../src/llm/sse');
const { OpenAICompatProvider } = require('../src/llm/openaiCompat');
const { PRESETS, presetConfig } = require('../src/llm/presets');

test('persona: 4개 언어 존재 + 미지원은 en 폴백', () => {
  assert.ok(persona('ko').includes('openNeko'));
  assert.ok(persona('en').includes('openNeko'));
  assert.ok(persona('ja').includes('openNeko'));
  assert.ok(persona('zh').includes('openNeko'));
  assert.equal(persona('zz'), PERSONA.en);
});

test('formatPrompt: 단일 턴은 메시지 그대로', () => {
  const p = formatPrompt([{ role: 'user', text: '안녕' }]);
  assert.equal(p, '안녕');
});

test('formatPrompt: 멀티턴은 이전 대화 + 지금 질문', () => {
  const p = formatPrompt([
    { role: 'user', text: '내 이름은 토마야' },
    { role: 'assistant', text: '반갑다냥!' },
    { role: 'user', text: '내 이름 뭐였지?' },
  ]);
  assert.match(p, /이전 대화/);
  assert.match(p, /나: 내 이름은 토마야/);
  assert.match(p, /너: 반갑다냥!/);
  assert.match(p, /지금 질문: 내 이름 뭐였지\?/);
});

test('historyToMessages: 최근 6턴을 role/content로', () => {
  const h = [{role:'user',text:'a'},{role:'assistant',text:'b'},{role:'user',text:'c'}];
  assert.deepEqual(historyToMessages(h), [
    {role:'user',content:'a'},{role:'assistant',content:'b'},{role:'user',content:'c'}]);
});

test('historyToMessages: 6턴 초과는 마지막 6개', () => {
  const h = Array.from({length:9}, (_,i)=>({role:'user',text:String(i)}));
  assert.equal(historyToMessages(h).length, 6);
  assert.equal(historyToMessages(h)[0].content, '3');
});

test('httpError: 상태코드→사유 코드', () => {
  assert.equal(httpError(401,'').code, 'AUTH');
  assert.equal(httpError(404,'').code, 'NOTFOUND');
  assert.equal(httpError(500,'boom').code, 'HTTP');
  assert.match(httpError(500,'boom').message, /boom|500/);
});

test('createSSEParser: data 라인만, 부분 청크 누적', () => {
  const feed = createSSEParser();
  assert.deepEqual(feed('data: {"a":1}\n\ndata: hel'), ['{"a":1}']);
  assert.deepEqual(feed('lo\n'), ['hello']);
  assert.deepEqual(feed('event: x\ndata: [DONE]\n'), ['[DONE]']);
});

function fakeFetchSSE(lines) {
  const enc = new TextEncoder();
  return async () => ({
    ok: true, status: 200,
    body: { getReader() { let i = 0; return { read() {
      if (i >= lines.length) return Promise.resolve({ done: true });
      return Promise.resolve({ done: false, value: enc.encode(lines[i++]) });
    } }; } },
  });
}

test('OpenAICompatProvider.chat: SSE delta 누적 + onDelta', async () => {
  const p = new OpenAICompatProvider({ baseURL: 'http://x/v1', apiKey: 'k', model: 'm' });
  p._fetch = fakeFetchSSE([
    'data: {"choices":[{"delta":{"content":"야"}}]}\n',
    'data: {"choices":[{"delta":{"content":"옹냥"}}]}\n',
    'data: [DONE]\n',
  ]);
  const deltas = [];
  const r = await p.chat({ history: [{ role:'user', text:'안녕' }], onDelta: t=>deltas.push(t) });
  assert.equal(r.text, '야옹냥');
  assert.deepEqual(deltas, ['야','옹냥']);
});

test('OpenAICompatProvider.chat: system 파라미터가 있으면 persona 대신 사용', async () => {
  const p = new OpenAICompatProvider({ baseURL: 'http://x/v1', apiKey: 'k', model: 'm', lang: 'ko' });
  let capturedBody = null;
  p._fetch = async (_url, opts) => {
    capturedBody = JSON.parse(opts.body);
    return fakeFetchSSE(['data: {"choices":[{"delta":{"content":"응"}}]}\n'])(_url, opts);
  };
  await p.chat({ history: [{ role:'user', text:'안녕' }], system: 'custom-system' });
  assert.equal(capturedBody.messages[0].role, 'system');
  assert.equal(capturedBody.messages[0].content, 'custom-system');
});

test('OpenAICompatProvider.chat: 401 → AUTH 에러', async () => {
  const p = new OpenAICompatProvider({ baseURL:'http://x/v1', apiKey:'bad', model:'m' });
  p._fetch = async () => ({ ok:false, status:401, text: async()=>'unauthorized' });
  await assert.rejects(p.chat({ history:[{role:'user',text:'x'}] }), e => e.code === 'AUTH');
});

test('OpenAICompatProvider.chat: body 없으면 빈 응답 (TypeError 아님)', async () => {
  const p = new OpenAICompatProvider({ baseURL:'http://x/v1', apiKey:'k', model:'m' });
  p._fetch = async () => ({ ok:true, status:200, body:null });
  await assert.rejects(p.chat({ history:[{role:'user',text:'x'}] }), e => /빈 응답/.test(e.message));
});

test('makeAbort: 타임아웃 abort는 ETIMEDOUT로 변환', async () => {
  const ab = makeAbort(undefined, 5);
  await new Promise((r) => ab.signal.addEventListener('abort', r));
  const err = ab.rethrow(Object.assign(new Error('aborted'), { name: 'AbortError' }));
  assert.equal(err.code, 'ETIMEDOUT');
});

test('makeAbort: 외부 signal 취소는 AbortError 그대로(ETIMEDOUT 아님)', () => {
  const ctrl = new AbortController();
  const ab = makeAbort(ctrl.signal, 30000);
  ctrl.abort();
  const orig = Object.assign(new Error('aborted'), { name: 'AbortError' });
  const err = ab.rethrow(orig);
  assert.equal(err, orig);
  assert.notEqual(err.code, 'ETIMEDOUT');
});

test('redactSecrets: 키 비슷한 값 마스킹', () => {
  assert.match(redactSecrets('Bearer sk-abcdef123456'), /Bearer •••/);
  assert.match(redactSecrets('{"api_key":"sk-secret123456"}'), /•••/);
  assert.doesNotMatch(redactSecrets('Authorization: Bearer sk-abcdef123456'), /abcdef123456/);
});

test('PRESETS: GPT-first 필수 프리셋 존재', () => {
  const ids = PRESETS.map(p => p.id);
  assert.deepEqual(ids, ['openai', 'ollama', 'custom']);
});

test('presetConfig: 프리셋 기본값 + override 병합', () => {
  const c = presetConfig('ollama', { model: 'llama3' });
  assert.equal(c.type, 'openai-compat');
  assert.equal(c.baseURL, 'http://localhost:11434/v1');
  assert.equal(c.model, 'llama3');
});

test('createProvider: config 없으면 OpenAI GPT 기본', () => {
  const p = createProvider();
  assert.equal(p.name, 'openai-compat');
  assert.equal(p.baseURL, DEFAULT_BASE_URL);
  assert.equal(p.model, DEFAULT_MODEL);
});

test('createProvider: openai-compatible 인스턴스 생성', () => {
  const p = createProvider({ type:'openai-compat', baseURL:'http://x/v1', model:'m' });
  assert.equal(p.name, 'openai-compat');
  assert.equal(p.baseURL, 'http://x/v1');
  assert.equal(p.model, 'm');
});
