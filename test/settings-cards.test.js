const { test } = require('node:test');
const assert = require('node:assert');
const { categorizeProviders, friendlyLabel } = require('../src/settings/cards');

const PRESETS = [
  { id: 'openai', label: 'OpenAI GPT', fields: ['apiKey', 'model'] },
  { id: 'ollama', label: 'Ollama (local)', fields: ['baseURL', 'model'] },
  { id: 'custom', label: 'Custom OpenAI-compatible', fields: ['baseURL', 'apiKey', 'model'] },
];

test('categorizeProviders: openai는 항상 ready 첫 번째 + 추천', () => {
  const { ready } = categorizeProviders({ presets: PRESETS, detected: [], currentPresetId: 'openai' });
  assert.equal(ready[0].presetId, 'openai');
  assert.equal(ready[0].recommended, true);
  assert.match(ready[0].subtitle, /OPENAI_API_KEY/);
});

test('categorizeProviders: 감지된 ollama는 ready에 들어가고 connect에서 빠진다', () => {
  const { ready, connect } = categorizeProviders({
    presets: PRESETS,
    detected: [{ presetId: 'ollama', source: 'local', models: ['llama3', 'gpt-oss'] }],
    currentPresetId: 'openai',
  });
  const readyIds = ready.map((c) => c.presetId);
  const connectIds = connect.map((c) => c.presetId);
  assert.ok(readyIds.includes('ollama'));
  assert.ok(!connectIds.includes('ollama'));
  const o = ready.find((c) => c.presetId === 'ollama');
  assert.match(o.subtitle, /Ready/);
  assert.match(o.subtitle, /llama3/);
});

test('categorizeProviders: 입력 필요한 custom은 connect에 남는다', () => {
  const { connect } = categorizeProviders({ presets: PRESETS, detected: [], currentPresetId: 'openai' });
  const ids = connect.map((c) => c.presetId);
  assert.ok(ids.includes('ollama'));
  assert.ok(ids.includes('custom'));
  assert.ok(!ids.includes('openai'));
});

test('categorizeProviders: currentPresetId가 currentId로 반영', () => {
  const r = categorizeProviders({ presets: PRESETS, detected: [], currentPresetId: 'custom' });
  assert.equal(r.currentId, 'custom');
});

test('friendlyLabel: 매핑 있으면 친근 라벨, 없으면 폴백', () => {
  assert.equal(friendlyLabel('openai', 'OpenAI GPT'), 'OpenAI GPT');
  assert.equal(friendlyLabel('ollama', 'x'), 'Ollama on this computer');
  assert.equal(friendlyLabel('unknown-id', 'fallback'), 'fallback');
});
