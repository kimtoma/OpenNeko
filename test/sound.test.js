const { test } = require('node:test');
const assert = require('node:assert');
const { RECIPES, createSounds } = require('../src/renderer/sound');

test('RECIPES: 5종 존재 + seq/dur 형태', () => {
  for (const name of ['chirp', 'pluck', 'land', 'success', 'error']) {
    const r = RECIPES[name];
    assert.ok(r, `missing ${name}`);
    assert.ok(Array.isArray(r.seq) && r.seq.length >= 1);
    assert.ok(typeof r.dur === 'number' && r.dur > 0);
  }
});

test('_shouldPlay: disabled면 항상 false', () => {
  let now = 0;
  const s = createSounds({ enabled: false, now: () => now });
  assert.equal(s._shouldPlay('chirp'), false);
});

test('_shouldPlay: enabled면 스로틀 간격 적용 (클럭 주입)', () => {
  let now = 0;
  const s = createSounds({ enabled: true, now: () => now });
  assert.equal(s._shouldPlay('chirp'), true);   // 첫 호출 OK
  now = 50;  assert.equal(s._shouldPlay('chirp'), false); // 120ms 내 재호출 차단
  now = 200; assert.equal(s._shouldPlay('chirp'), true);  // 간격 지나면 OK
  // 이름별로 독립 스로틀
  assert.equal(s._shouldPlay('pluck'), true);
});

test('setEnabled: 상태 토글이 _shouldPlay에 반영', () => {
  let now = 0;
  const s = createSounds({ enabled: true, now: () => now });
  s.setEnabled(false);
  assert.equal(s._shouldPlay('chirp'), false);
  s.setEnabled(true); now = 1000;
  assert.equal(s._shouldPlay('chirp'), true);
});

test('알 수 없는 이름은 _shouldPlay false', () => {
  const s = createSounds({ enabled: true, now: () => 0 });
  assert.equal(s._shouldPlay('nope'), false);
});
