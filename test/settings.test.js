const { test } = require('node:test');
const assert = require('node:assert');
const os = require('node:os');
const fs = require('node:fs');
const path = require('node:path');
const { makeStore } = require('../src/settings');

function tmpDir() { return fs.mkdtempSync(path.join(os.tmpdir(), 'on-set-')); }
const fakeSafe = {
  isEncryptionAvailable: () => true,
  encryptString: (s) => Buffer.from('enc:' + s),
  decryptString: (b) => b.toString().replace(/^enc:/, ''),
};

test('save/load: 비밀 아닌 값 보존 + 키 암호화 라운드트립', () => {
  const dir = tmpDir();
  const store = makeStore({ dir, safeStorage: fakeSafe });
  store.save({ provider: { preset:'openai', type:'openai-compat', baseURL:'http://x/v1', model:'m' }, apiKey: 'sk-123' });
  const raw = JSON.parse(fs.readFileSync(path.join(dir, 'settings.json'), 'utf8'));
  assert.equal(raw.provider.baseURL, 'http://x/v1');
  assert.ok(!JSON.stringify(raw).includes('sk-123'), '평문 키가 파일에 있으면 안 됨');
  const loaded = store.load();
  assert.equal(loaded.provider.model, 'm');
  assert.equal(loaded.apiKey, 'sk-123');
});

test('load: 파일 없으면 null provider', () => {
  const store = makeStore({ dir: tmpDir(), safeStorage: fakeSafe });
  assert.equal(store.load().provider, null);
});

test('makeStore: sound 라운드트립 + 기본값', () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'openneko-snd-'));
  const store = makeStore({ dir, safeStorage: null });
  // 기본: sound 없으면 enabled true
  assert.deepEqual(store.load().sound, { enabled: true });
  // 저장 후 보존
  store.save({ provider: { preset: 'openai' }, apiKey: '', sound: { enabled: false } });
  assert.deepEqual(store.load().sound, { enabled: false });
  assert.deepEqual(store.load().provider, { preset: 'openai' });
});

test('makeStore: lang 라운드트립 + 기본 null', () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'openneko-lang-'));
  const store = makeStore({ dir, safeStorage: null });
  assert.equal(store.load().lang, null);            // 기본 자동(=null)
  store.save({ provider: { preset: 'openai' }, apiKey: '', sound: { enabled: true }, lang: 'ja' });
  assert.equal(store.load().lang, 'ja');
  // provider만 다시 저장하면서 lang을 같이 실어야 보존됨(settings-save 핸들러가 이 패턴을 따른다)
  const c = store.load();
  store.save({ provider: { preset: 'custom' }, apiKey: '', sound: c.sound, lang: c.lang });
  assert.equal(store.load().lang, 'ja');            // provider 바꿔도 언어 유지
  assert.deepEqual(store.load().provider, { preset: 'custom' });
});

test('neighbor 기본값: enabled true, displayName 빈문자', () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'cn-neighbor-'));
  const store = makeStore({ dir, safeStorage: null });
  const l = store.load();
  assert.deepStrictEqual(l.neighbor, { enabled: true, displayName: '' });
});

test('neighbor 저장/로드 병합', () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'cn-neighbor-merge-'));
  const store = makeStore({ dir, safeStorage: null });
  const cur = store.load();
  store.save({ ...cur, neighbor: { enabled: false, displayName: '경수냥' } });
  const l = store.load();
  assert.strictEqual(l.neighbor.enabled, false);
  assert.strictEqual(l.neighbor.displayName, '경수냥');
});

test('peerId 저장/로드', () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'cn-peerid-'));
  const store = makeStore({ dir, safeStorage: null });
  store.save({ ...store.load(), peerId: 'fixed-id' });
  assert.strictEqual(store.load().peerId, 'fixed-id');
});

test('neighbor shape 비정상 입력 정규화', () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'cn-neighbor-invalid-'));
  const store = makeStore({ dir, safeStorage: null });
  store.save({ ...store.load(), neighbor: 'garbage' });
  assert.deepStrictEqual(store.load().neighbor, { enabled: true, displayName: '' });
});

test('catName 기본값은 빈 문자열', () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'cn-catname-default-'));
  const store = makeStore({ dir, safeStorage: null });
  assert.strictEqual(store.load().catName, '');
});

test('catName 저장/로드', () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'cn-catname-save-'));
  const store = makeStore({ dir, safeStorage: null });
  store.save({ ...store.load(), catName: '나비' });
  assert.strictEqual(store.load().catName, '나비');
});

test('마이그레이션: catName 비고 neighbor.displayName 있으면 그 값', () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'cn-mig-'));
  fs.writeFileSync(path.join(dir, 'settings.json'), JSON.stringify({ neighbor: { enabled: true, displayName: '치즈' } }));
  const store = makeStore({ dir, safeStorage: null });
  assert.strictEqual(store.load().catName, '치즈');
});

test('마이그레이션: catName 이미 있으면 유지(neighbor.displayName 무시)', () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'cn-mig2-'));
  fs.writeFileSync(path.join(dir, 'settings.json'), JSON.stringify({ catName: '나비', neighbor: { enabled: true, displayName: '치즈' } }));
  const store = makeStore({ dir, safeStorage: null });
  assert.strictEqual(store.load().catName, '나비');
});
