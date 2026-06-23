// test/lan-peers.test.js
const test = require('node:test');
const assert = require('node:assert');
const P = require('../src/lan/peers');

const base = { id: 'b', name: '냥', skin: 'black', presence: 'idle', lastSeen: 100 };

test('addOrUpdate: 추가 + 같은 id 병합(중복 방지)', () => {
  let m = P.addOrUpdate({}, base);
  assert.strictEqual(P.list(m).length, 1);
  m = P.addOrUpdate(m, { id: 'b', name: '냥2', skin: 'white', lastSeen: 200 });
  assert.strictEqual(P.list(m).length, 1);
  assert.strictEqual(m.b.name, '냥2');
  assert.strictEqual(m.b.skin, 'white');
  assert.strictEqual(m.b.presence, 'idle'); // 미지정 필드 보존
});
test('remove', () => {
  const m = P.addOrUpdate({}, base);
  assert.deepStrictEqual(P.remove(m, 'b'), {});
  assert.deepStrictEqual(P.remove({}, 'x'), {});
});
test('setPresence: 없는 id는 무변화', () => {
  const m = P.addOrUpdate({}, base);
  assert.strictEqual(P.setPresence(m, 'b', 'coding').b.presence, 'coding');
  assert.deepStrictEqual(P.setPresence(m, 'z', 'coding'), m);
});
test('touch: lastSeen 갱신', () => {
  const m = P.addOrUpdate({}, base);
  assert.strictEqual(P.touch(m, 'b', 500).b.lastSeen, 500);
});
test('prune: ttl 지난 피어 제거', () => {
  let m = P.addOrUpdate({}, { ...base, lastSeen: 100 });
  m = P.addOrUpdate(m, { id: 'c', name: 'c', skin: 'white', lastSeen: 900 });
  const pruned = P.prune(m, 1000, 500); // now=1000, ttl=500 → b(100) 제거, c(900) 유지
  assert.deepStrictEqual(Object.keys(pruned), ['c']);
});
test('list: id 정렬, 불변', () => {
  let m = P.addOrUpdate({}, { id: 'z', name: 'z', skin: 'white', lastSeen: 1 });
  m = P.addOrUpdate(m, { id: 'a', name: 'a', skin: 'white', lastSeen: 1 });
  assert.deepStrictEqual(P.list(m).map((p) => p.id), ['a', 'z']);
});
test('불변성: 원본 map 변경 안 함', () => {
  const m = P.addOrUpdate({}, base);
  P.remove(m, 'b');
  assert.strictEqual(P.list(m).length, 1);
});
