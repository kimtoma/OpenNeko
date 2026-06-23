const { test } = require('node:test');
const assert = require('node:assert');
const { parseBehind, isDirty, updateDecision } = require('../src/updater');

test('parseBehind: 숫자 파싱, 음수/비정상은 0', () => {
  assert.equal(parseBehind('3\n'), 3);
  assert.equal(parseBehind('0'), 0);
  assert.equal(parseBehind(''), 0);
  assert.equal(parseBehind('abc'), 0);
  assert.equal(parseBehind('-2'), 0);
});

test('isDirty: porcelain 비면 clean, 내용 있으면 dirty', () => {
  assert.equal(isDirty(''), false);
  assert.equal(isDirty('   \n'), false);
  assert.equal(isDirty(' M src/main.js\n'), true);
});

test('updateDecision: git 아니면 불가', () => {
  assert.deepEqual(updateDecision({ isGit: false, behind: 5, dirty: false }), { available: false, reason: 'not-git', behind: 0 });
});

test('updateDecision: 더티면 불가(behind 보존)', () => {
  const d = updateDecision({ isGit: true, behind: 2, dirty: true });
  assert.equal(d.available, false);
  assert.equal(d.reason, 'dirty');
  assert.equal(d.behind, 2);
});

test('updateDecision: 뒤처지고 clean이면 가능', () => {
  assert.deepEqual(updateDecision({ isGit: true, behind: 4, dirty: false }), { available: true, reason: 'behind', behind: 4 });
});

test('updateDecision: 최신이면 up-to-date', () => {
  assert.deepEqual(updateDecision({ isGit: true, behind: 0, dirty: false }), { available: false, reason: 'up-to-date', behind: 0 });
});
