const { test } = require('node:test');
const assert = require('node:assert');
const { categorizeProviders, friendlyLabel } = require('../src/settings/cards');

const PRESETS = [
  { id: 'chatgpt-oauth', label: 'OpenAI Login (Codex)', fields: ['model'], cliBin: 'codex', recommended: true },
  { id: 'claude-oauth', label: 'Claude Login', fields: ['model'], cliBin: 'claude' },
  { id: 'gemini-oauth', label: 'Gemini Login', fields: ['model'], cliBin: 'gemini' },
  { id: 'ollama', label: 'Ollama', fields: ['baseURL', 'model'], local: true },
  { id: 'local-openai', label: 'Local OpenAI-compatible', fields: ['baseURL', 'model'], local: true },
  { id: 'gemini', label: 'Gemini API Key', fields: ['apiKey', 'model'], requiresApiKey: true },
  { id: 'claude', label: 'Claude API Key', fields: ['apiKey', 'model'], requiresApiKey: true },
  { id: 'custom', label: 'Custom OpenAI-compatible', fields: ['baseURL', 'apiKey', 'model'] },
];

test('categorizeProviders: 감지되지 않은 provider는 ready에 임의 추가하지 않음', () => {
  const { ready } = categorizeProviders({ presets: PRESETS, detected: [], currentPresetId: 'chatgpt-oauth' });
  assert.deepEqual(ready, []);
});

test('categorizeProviders: 감지된 Gemini API key는 ready에 들어가고 connect에서 빠진다', () => {
  const { ready, connect } = categorizeProviders({
    presets: PRESETS,
    detected: [{ presetId: 'gemini', source: 'env' }],
    currentPresetId: 'chatgpt-oauth',
  });
  const readyIds = ready.map((c) => c.presetId);
  const connectIds = connect.map((c) => c.presetId);
  assert.ok(readyIds.includes('gemini'));
  assert.ok(!connectIds.includes('gemini'));
  const g = ready.find((c) => c.presetId === 'gemini');
  assert.match(g.subtitle, /Ready/);
});

test('categorizeProviders: 감지된 OAuth CLI는 ready에 들어간다', () => {
  const { ready, connect } = categorizeProviders({
    presets: PRESETS,
    detected: [
      { presetId: 'chatgpt-oauth', source: 'oauth' },
      { presetId: 'claude-oauth', source: 'oauth' },
      { presetId: 'gemini-oauth', source: 'oauth' },
    ],
    currentPresetId: 'chatgpt-oauth',
  });
  const chatgpt = ready.find((c) => c.presetId === 'chatgpt-oauth');
  assert.ok(chatgpt);
  assert.equal(chatgpt.recommended, true);
  assert.ok(ready.some((c) => c.presetId === 'claude-oauth'));
  assert.ok(ready.some((c) => c.presetId === 'gemini-oauth'));
  assert.ok(!connect.some((c) => c.presetId === 'chatgpt-oauth'));
});

test('categorizeProviders: 감지된 Ollama는 ready에 모델 목록을 싣는다', () => {
  const { ready, connect } = categorizeProviders({
    presets: PRESETS,
    detected: [{ presetId: 'ollama', source: 'local', models: ['gemma4:e2b'] }],
    currentPresetId: 'chatgpt-oauth',
  });
  const o = ready.find((c) => c.presetId === 'ollama');
  assert.ok(o);
  assert.deepEqual(o.models, ['gemma4:e2b']);
  assert.ok(!connect.some((c) => c.presetId === 'ollama'));
});

test('categorizeProviders: 입력/설치 필요한 서비스는 connect에 남는다', () => {
  const { connect } = categorizeProviders({ presets: PRESETS, detected: [], currentPresetId: 'chatgpt-oauth' });
  const ids = connect.map((c) => c.presetId);
  assert.ok(ids.includes('chatgpt-oauth'));
  assert.ok(ids.includes('claude-oauth'));
  assert.ok(ids.includes('gemini-oauth'));
  assert.ok(ids.includes('ollama'));
  assert.ok(ids.includes('local-openai'));
  assert.ok(ids.includes('gemini'));
  assert.ok(ids.includes('claude'));
  assert.ok(ids.includes('custom'));
});

test('categorizeProviders: currentPresetId가 currentId로 반영', () => {
  const r = categorizeProviders({ presets: PRESETS, detected: [], currentPresetId: 'custom' });
  assert.equal(r.currentId, 'custom');
});

test('friendlyLabel: 매핑 있으면 친근 라벨, 없으면 폴백', () => {
  assert.equal(friendlyLabel('chatgpt-oauth', 'x'), 'OpenAI Login');
  assert.equal(friendlyLabel('claude-oauth', 'x'), 'Claude Login');
  assert.equal(friendlyLabel('gemini-oauth', 'x'), 'Gemini Login');
  assert.equal(friendlyLabel('gemini', 'x'), 'Gemini API Key');
  assert.equal(friendlyLabel('claude', 'x'), 'Claude API Key');
  assert.equal(friendlyLabel('unknown-id', 'fallback'), 'fallback');
});
