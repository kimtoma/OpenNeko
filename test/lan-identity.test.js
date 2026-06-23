const test = require('node:test');
const assert = require('node:assert');
const { ensurePeerId, displayName } = require('../src/lan/identity');

test('ensurePeerId: 저장값 있으면 유지', () => {
  assert.strictEqual(ensurePeerId('keep-me', () => 'new'), 'keep-me');
});
test('ensurePeerId: 비면 생성', () => {
  assert.strictEqual(ensurePeerId('', () => 'gen'), 'gen');
  assert.strictEqual(ensurePeerId(undefined, () => 'gen'), 'gen');
});
test('displayName: 비면 fallback', () => {
  assert.strictEqual(displayName('', '이웃 고양이'), '이웃 고양이');
  assert.strictEqual(displayName('   ', '이웃 고양이'), '이웃 고양이');
  assert.strictEqual(displayName('경수', '이웃 고양이'), '경수');
});
test('displayName: 64자 컷', () => {
  assert.strictEqual(displayName('a'.repeat(100), 'x').length, 64);
});
