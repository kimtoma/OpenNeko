const { test } = require('node:test');
const assert = require('node:assert');
const { PRESETS, resolveApiKey } = require('../src/llm/presets');
const { detectProviders } = require('../src/llm/detect');

test('presets: OpenAI preset has OPENAI_API_KEY env fallback', () => {
  const byId = Object.fromEntries(PRESETS.map((p) => [p.id, p]));
  assert.equal(byId.openai.envKey, 'OPENAI_API_KEY');
  assert.equal(byId.ollama.type, 'openai-compat');
  assert.equal(byId.custom.type, 'openai-compat');
});

test('resolveApiKey: 저장된 키가 있으면 그것을 우선', () => {
  assert.equal(resolveApiKey('openai', 'saved-key', { OPENAI_API_KEY: 'env-key' }), 'saved-key');
});

test('resolveApiKey: 저장 키 없으면 OPENAI_API_KEY 폴백', () => {
  assert.equal(resolveApiKey('openai', undefined, { OPENAI_API_KEY: 'env-key' }), 'env-key');
});

test('resolveApiKey: envKey 없는 프리셋은 저장 키 그대로', () => {
  assert.equal(resolveApiKey('ollama', 'k', {}), 'k');
  assert.equal(resolveApiKey('custom', undefined, { OPENAI_API_KEY: 'x' }), undefined);
});

function deps({ env = {}, ollama = false } = {}) {
  return {
    env,
    fetch: async (url) => {
      if (ollama && url.includes('11434')) {
        return { ok: true, json: async () => ({ models: [{ name: 'llama3' }, { name: 'gpt-oss' }] }) };
      }
      throw new Error('ECONNREFUSED');
    },
  };
}

test('detectProviders: OpenAI env 키를 감지', async () => {
  const r = await detectProviders(deps({ env: { OPENAI_API_KEY: 'x' } }));
  const openai = r.find((d) => d.presetId === 'openai');
  assert.ok(openai);
  assert.equal(openai.source, 'env');
  assert.ok(openai.ready);
});

test('detectProviders: 로컬 Ollama + 모델 목록 감지', async () => {
  const r = await detectProviders(deps({ ollama: true }));
  const o = r.find((d) => d.presetId === 'ollama');
  assert.ok(o && o.ready);
  assert.equal(o.source, 'local');
  assert.deepEqual(o.models, ['llama3', 'gpt-oss']);
});

test('detectProviders: Ollama 꺼져 있으면 목록에 없음', async () => {
  const r = await detectProviders(deps({ ollama: false }));
  assert.ok(!r.some((d) => d.presetId === 'ollama'));
});

test('detectProviders: 아무것도 없으면 빈 배열', async () => {
  const r = await detectProviders(deps({}));
  assert.deepEqual(r, []);
});

test('detectProviders: 깨진 Ollama 모델 항목도 함수 전체를 깨지 않음', async () => {
  const d = {
    env: {},
    fetch: async () => ({ ok: true, json: async () => ({ models: [{ name: 'ok' }, null, {}, 'bad'] }) }),
  };
  const r = await detectProviders(d);
  const o = r.find((x) => x.presetId === 'ollama');
  assert.ok(o);
  assert.deepEqual(o.models, ['ok']);
});

test('detectProviders: fetch 미제공이어도 env 감지는 동작', async () => {
  const r = await detectProviders({ env: { OPENAI_API_KEY: 'x' } });
  assert.ok(r.some((d) => d.presetId === 'openai'));
  assert.ok(!r.some((d) => d.presetId === 'ollama'));
});
