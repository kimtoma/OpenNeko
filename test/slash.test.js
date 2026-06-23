const { test } = require('node:test');
const assert = require('node:assert');
const { parseSlash, matchCommands } = require('../src/slash');

// --- parseSlash ---

test('parseSlash: /help → {cmd:help, args:""}', () => {
  const r = parseSlash('/help');
  assert.deepEqual(r, { cmd: 'help', args: '' });
});

test('parseSlash: /translate 안녕 거기 → {cmd:translate, args:"안녕 거기"}', () => {
  const r = parseSlash('/translate 안녕 거기');
  assert.deepEqual(r, { cmd: 'translate', args: '안녕 거기' });
});

test('parseSlash: 일반 텍스트 → null', () => {
  assert.equal(parseSlash('안녕'), null);
});

test('parseSlash: / 만 → {cmd:"", args:""}', () => {
  const r = parseSlash('/');
  assert.deepEqual(r, { cmd: '', args: '' });
});

test('parseSlash: 앞 공백 있으면 null (슬래시 명령 아님)', () => {
  assert.equal(parseSlash(' /x'), null);
});

test('parseSlash: cmd은 소문자로 정규화', () => {
  const r = parseSlash('/TRANSLATE Hello');
  assert.deepEqual(r, { cmd: 'translate', args: 'Hello' });
});

test('parseSlash: 빈 문자열 → null', () => {
  assert.equal(parseSlash(''), null);
});

test('parseSlash: args 양쪽 공백 트림', () => {
  const r = parseSlash('/skin  black ');
  assert.deepEqual(r, { cmd: 'skin', args: 'black' });
});

// --- matchCommands ---

const catalog = [
  { name: 'translate', kind: 'skill', desc: 'Translate text' },
  { name: 'explain', kind: 'skill', desc: 'Explain code' },
  { name: 'help', kind: 'builtin', desc: 'Show help' },
  { name: 'reset', kind: 'builtin', desc: 'Reset chat' },
  { name: 'skin', kind: 'app', desc: 'Change skin' },
];

test('matchCommands: 빈 prefix → 전체(이름순)', () => {
  const r = matchCommands('', catalog);
  assert.deepEqual(r.map((c) => c.name), ['explain', 'help', 'reset', 'skin', 'translate']);
});

test('matchCommands: prefix 필터 (t → translate)', () => {
  const r = matchCommands('t', catalog);
  assert.deepEqual(r.map((c) => c.name), ['translate']);
});

test('matchCommands: 대소문자 무시', () => {
  const r = matchCommands('TR', catalog);
  assert.deepEqual(r.map((c) => c.name), ['translate']);
});

test('matchCommands: 매치 없으면 빈 배열', () => {
  const r = matchCommands('zzz', catalog);
  assert.deepEqual(r, []);
});

test('matchCommands: 복수 매치 이름순 정렬', () => {
  const r = matchCommands('e', catalog);
  assert.deepEqual(r.map((c) => c.name), ['explain']);
});

test('matchCommands: catalog 없으면 빈 배열', () => {
  const r = matchCommands('h');
  assert.deepEqual(r, []);
});
