const { test } = require('node:test');
const assert = require('node:assert');
const { augmentPath, spawnEnv } = require('../src/llm/pathEnv');

test('augmentPath: 홈브루/유저 bin 디렉토리를 PATH 앞에 보강', () => {
  const out = augmentPath('/usr/bin:/bin', '/Users/me', 'darwin');
  const parts = out.split(':');
  assert.ok(parts.includes('/opt/homebrew/bin'));
  assert.ok(parts.includes('/usr/local/bin'));
  assert.ok(parts.includes('/Users/me/.local/bin'));
  assert.ok(parts.includes('/usr/bin')); // 기존 항목 보존
});

test('augmentPath: 이미 있는 디렉토리는 중복 추가 안 함', () => {
  const out = augmentPath('/opt/homebrew/bin:/usr/bin', '/Users/me', 'darwin');
  assert.equal(out.split(':').filter((p) => p === '/opt/homebrew/bin').length, 1);
});

test('augmentPath: PATH가 비어도 동작', () => {
  const out = augmentPath('', '/Users/me', 'darwin');
  assert.ok(out.split(':').includes('/opt/homebrew/bin'));
});

test('spawnEnv: 기존 env 보존하고 PATH만 보강', () => {
  const env = spawnEnv({ PATH: '/usr/bin', FOO: 'bar' }, 'darwin');
  assert.equal(env.FOO, 'bar');
  assert.ok(env.PATH.split(':').includes('/opt/homebrew/bin'));
  assert.ok(env.PATH.split(':').includes('/usr/bin'));
});

test('augmentPath(win32): ; 구분자 + npm 전역 디렉토리 보강, 기존 보존', () => {
  const out = augmentPath('C:\\Windows\\System32', 'C:\\Users\\me', 'win32');
  const parts = out.split(';');
  assert.ok(parts.some((p) => p.endsWith('npm')));            // %APPDATA%\\npm
  assert.ok(parts.some((p) => p.endsWith('WindowsApps')));    // winget/Store
  assert.ok(parts.includes('C:\\Windows\\System32'));         // 기존 항목 보존
});

test('augmentPath(win32): 빈 PATH도 ;로 join되고 npm 포함', () => {
  const out = augmentPath('', 'C:\\Users\\me', 'win32');
  assert.ok(out.includes(';'));
  assert.ok(out.split(';').some((p) => p.endsWith('npm')));
});

test('spawnEnv(win32): PATH를 ;로 보강', () => {
  const env = spawnEnv({ PATH: 'C:\\Windows', FOO: 'bar' }, 'win32');
  assert.equal(env.FOO, 'bar');
  assert.ok(env.PATH.split(';').includes('C:\\Windows'));
  assert.ok(env.PATH.split(';').some((p) => p.endsWith('npm')));
});
