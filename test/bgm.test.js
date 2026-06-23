const { test } = require('node:test');
const assert = require('node:assert');
const {
  BGM_PRESETS,
  buildYoutubeMusicSearchUrl,
  dateKey,
  normalizePreference,
  pickDailyBgm,
} = require('../src/bgm');

test('dateKey: local date를 YYYY-MM-DD로 포맷', () => {
  assert.equal(dateKey(new Date(2026, 5, 24, 9, 30)), '2026-06-24');
});

test('pickDailyBgm: 같은 날짜는 같은 BGM을 고른다', () => {
  const a = pickDailyBgm(new Date(2026, 5, 24, 9));
  const b = pickDailyBgm(new Date(2026, 5, 24, 23));
  assert.equal(a.id, b.id);
  assert.equal(a.dateKey, '2026-06-24');
  assert.equal(a.service, 'YouTube Music');
  assert.match(a.url, /^https:\/\/music\.youtube\.com\/search\?q=/);
});

test('pickDailyBgm: 취향 힌트를 검색어와 seed에 반영한다', () => {
  const bgm = pickDailyBgm(new Date(2026, 5, 24, 9), { preference: 'jazz cafe', lang: 'ko' });
  assert.match(bgm.query, /jazz cafe/);
  assert.match(decodeURIComponent(bgm.url), /jazz cafe/);
  assert.equal(bgm.personalized, true);
});

test('pickDailyBgm: 프로필은 seed에만 쓰고 URL에는 노출하지 않는다', () => {
  const bgm = pickDailyBgm(new Date(2026, 5, 24, 9), {
    profile: { name: 'Alice', birthDate: '1990-01-02', calendar: 'solar' },
    lang: 'en',
  });
  assert.equal(bgm.personalized, true);
  assert.doesNotMatch(decodeURIComponent(bgm.url), /Alice|1990-01-02/);
});

test('buildYoutubeMusicSearchUrl: 검색어를 인코딩한다', () => {
  assert.equal(
    buildYoutubeMusicSearchUrl('lofi coding BGM'),
    'https://music.youtube.com/search?q=lofi%20coding%20BGM',
  );
});

test('normalizePreference: 긴/위험한 입력을 검색용으로 정리한다', () => {
  const s = normalizePreference(`  <jazz>\n${'x'.repeat(120)}`);
  assert.ok(!s.includes('<'));
  assert.ok(!s.includes('>'));
  assert.ok(s.length <= 80);
});

test('BGM_PRESETS: YouTube Music 검색에 필요한 필드 포함', () => {
  for (const p of BGM_PRESETS) {
    assert.ok(p.id);
    assert.ok(p.title);
    assert.ok(Array.isArray(p.terms));
    assert.ok(p.terms.length > 0);
  }
});
