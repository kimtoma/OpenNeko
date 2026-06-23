const test = require('node:test');
const assert = require('node:assert');
const { encode, parse, coarsePresence, TYPES, PRESENCE } = require('../src/lan/protocol');

test('encode→parse 왕복(hello)', () => {
  const m = { t: 'hello', id: 'abc', name: '냥', skin: 'black' };
  assert.deepStrictEqual(parse(encode(m)), m);
});
test('presence 검증: 잘못된 값 거부', () => {
  assert.strictEqual(parse('{"t":"presence","state":"dancing"}'), null);
  assert.deepStrictEqual(parse('{"t":"presence","state":"coding"}'), { t: 'presence', state: 'coding' });
});
test('greeting: key 정수만', () => {
  assert.deepStrictEqual(parse('{"t":"greeting","key":2}'), { t: 'greeting', key: 2 });
  assert.strictEqual(parse('{"t":"greeting","key":"x"}'), null);
});
test('미지 타입/깨진 JSON/초과 크기 → null', () => {
  assert.strictEqual(parse('{"t":"nope"}'), null);
  assert.strictEqual(parse('not json'), null);
  assert.strictEqual(parse('{"t":"hello","id":"' + 'x'.repeat(3000) + '"}'), null);
});
test('hello 필드 길이/타입 검증', () => {
  assert.strictEqual(parse('{"t":"hello"}'), null); // id 없음
  const longName = '{"t":"hello","id":"a","name":"' + 'y'.repeat(200) + '","skin":"white"}';
  assert.strictEqual(parse(longName).name.length, 64); // name 64자 컷
});
test('coarsePresence 매핑', () => {
  assert.strictEqual(coarsePresence('typing'), 'typing');
  assert.strictEqual(coarsePresence('coding'), 'coding');
  assert.strictEqual(coarsePresence('thinking'), 'coding');
  assert.strictEqual(coarsePresence('nap'), 'away');
  assert.strictEqual(coarsePresence('idle'), 'idle');
  assert.strictEqual(coarsePresence('hover'), 'idle');
});
test('encode 잘못된 메시지는 throw', () => {
  assert.throws(() => encode({ t: 'nope' }));
});
test('TYPES/PRESENCE 노출', () => {
  assert.ok(TYPES.includes('wave'));
  assert.deepStrictEqual(PRESENCE, ['idle', 'coding', 'typing', 'away']);
});
