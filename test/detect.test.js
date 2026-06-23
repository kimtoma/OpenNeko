const { test } = require('node:test');
const assert = require('node:assert');
const { PRESETS, resolveApiKey } = require('../src/llm/presets');
const { detectProviders } = require('../src/llm/detect');

test('presets: OAuth / local / API key preset metadata', () => {
  const byId = Object.fromEntries(PRESETS.map((p) => [p.id, p]));
  assert.equal(byId['chatgpt-oauth'].type, 'codex-cli');
  assert.equal(byId['chatgpt-oauth'].cliBin, 'codex');
  assert.equal(byId['claude-oauth'].type, 'claude-cli');
  assert.equal(byId['claude-oauth'].cliBin, 'claude');
  assert.equal(byId['gemini-oauth'].type, 'gemini-cli');
  assert.equal(byId['gemini-oauth'].cliBin, 'gemini');
  assert.equal(byId.ollama.type, 'openai-compat');
  assert.equal(byId.ollama.local, true);
  assert.equal(byId['local-openai'].local, true);
  assert.equal(byId.gemini.type, 'gemini');
  assert.equal(byId.gemini.envKey, 'GEMINI_API_KEY');
  assert.equal(byId.claude.type, 'anthropic');
  assert.equal(byId.claude.envKey, 'ANTHROPIC_API_KEY');
  assert.equal(byId.custom.type, 'openai-compat');
});

test('resolveApiKey: 저장된 키가 있으면 그것을 우선', () => {
  assert.equal(resolveApiKey('custom', 'saved-key', { CUSTOM_API_KEY: 'env-key' }), 'saved-key');
});

test('resolveApiKey: envKey 없는 프리셋은 저장 키 그대로', () => {
  assert.equal(resolveApiKey('custom', undefined, { CUSTOM_API_KEY: 'x' }), undefined);
});

test('resolveApiKey: 저장 키 없으면 provider envKey 폴백', () => {
  assert.equal(resolveApiKey('gemini', undefined, { GEMINI_API_KEY: 'g-env' }), 'g-env');
  assert.equal(resolveApiKey('gemini', undefined, { GOOGLE_API_KEY: 'google-env' }), 'google-env');
  assert.equal(resolveApiKey('claude', undefined, { ANTHROPIC_API_KEY: 'a-env' }), 'a-env');
});

test('detectProviders: Codex OpenAI OAuth 로그인을 감지', async () => {
  const r = await detectProviders({
    env: {},
    which: (bin) => bin === 'codex',
    execFile: async () => ({ stdout: 'Logged in using ChatGPT', stderr: '' }),
  });
  const codex = r.find((d) => d.presetId === 'chatgpt-oauth');
  assert.ok(codex);
  assert.equal(codex.source, 'oauth');
  assert.ok(codex.ready);
});

test('detectProviders: codex 미로그인이면 OpenAI OAuth ready 제외', async () => {
  const r = await detectProviders({
    env: {},
    which: (bin) => bin === 'codex',
    execFile: async () => ({ stdout: 'Not logged in', stderr: '' }),
  });
  assert.ok(!r.some((d) => d.presetId === 'chatgpt-oauth'));
});

test('detectProviders: Claude/Gemini OAuth CLI 설치를 ready로 감지', async () => {
  const r = await detectProviders({
    env: {},
    which: (bin) => bin === 'claude' || bin === 'gemini',
  });
  const byId = Object.fromEntries(r.map((d) => [d.presetId, d]));
  assert.equal(byId['claude-oauth'].source, 'oauth');
  assert.equal(byId['claude-oauth'].detail, 'claude');
  assert.equal(byId['gemini-oauth'].source, 'oauth');
  assert.equal(byId['gemini-oauth'].detail, 'gemini');
});

test('detectProviders: Gemini/Claude env 키를 ready로 감지', async () => {
  const r = await detectProviders({ env: { GEMINI_API_KEY: 'g', ANTHROPIC_API_KEY: 'a' } });
  const byId = Object.fromEntries(r.map((d) => [d.presetId, d]));
  assert.equal(byId.gemini.source, 'env');
  assert.equal(byId.gemini.detail, 'GEMINI_API_KEY');
  assert.equal(byId.claude.source, 'env');
  assert.equal(byId.claude.detail, 'ANTHROPIC_API_KEY');
});

test('detectProviders: Ollama local server와 모델 목록을 감지', async () => {
  const r = await detectProviders({
    fetch: async (url) => ({
      ok: String(url).includes('/api/tags'),
      json: async () => ({ models: [{ name: 'gemma4:e2b' }, { model: 'llama3.2' }] }),
    }),
  });
  const o = r.find((d) => d.presetId === 'ollama');
  assert.ok(o);
  assert.equal(o.source, 'local');
  assert.equal(o.model, 'gemma4:e2b');
  assert.deepEqual(o.models, ['gemma4:e2b', 'llama3.2']);
});

test('detectProviders: 아무것도 없으면 빈 배열', async () => {
  const r = await detectProviders({});
  assert.deepEqual(r, []);
});

test('detectProviders: 알 수 없는 env-only 키는 무시', async () => {
  const r = await detectProviders({ env: { CUSTOM_API_KEY: 'x' } });
  assert.deepEqual(r, []);
});
