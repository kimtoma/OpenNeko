const { test } = require('node:test');
const assert = require('node:assert');
const { STRINGS, SUPPORTED, normalizeLang, resolveLang, createI18n } = require('../src/i18n');

test('SUPPORTED = ko/en/ja/zh', () => assert.deepEqual(SUPPORTED, ['ko','en','ja','zh']));

test('normalizeLang: 로케일 → 코드', () => {
  assert.equal(normalizeLang('ko-KR'), 'ko');
  assert.equal(normalizeLang('en-US'), 'en');
  assert.equal(normalizeLang('ja'), 'ja');
  assert.equal(normalizeLang('zh-Hans-CN'), 'zh');
  assert.equal(normalizeLang('zh-CN'), 'zh');
  assert.equal(normalizeLang('fr-FR'), null);
});

test('resolveLang: 저장값 > OS > en', () => {
  assert.equal(resolveLang('ja', 'ko-KR'), 'ja');
  assert.equal(resolveLang(null, 'ko-KR'), 'ko');
  assert.equal(resolveLang(null, 'fr-FR'), 'en');
  assert.equal(resolveLang('zz', 'ja'), 'ja'); // 미지원 저장값 무시 → OS
});

test('t: 키 반환 / 폴백 / 보간 / 함수값', () => {
  const { t } = createI18n('en');
  assert.equal(typeof t('menu.settings'), 'string');
  assert.equal(t('no.such.key'), 'no.such.key');          // 폴백 후 key
  assert.match(t('settings.nowAnswers', { name: 'OpenAI GPT' }), /OpenAI GPT/); // 보간/함수
});

test('모든 언어가 동일 키 집합 (번역 누락 검출)', () => {
  const keysOf = (o, p = '') => Object.entries(o).flatMap(([k, v]) =>
    (v && typeof v === 'object' && !Array.isArray(v)) ? keysOf(v, p + k + '.') : [p + k]);
  const ko = new Set(keysOf(STRINGS.ko));
  for (const lang of ['en', 'ja', 'zh']) {
    const cur = new Set(keysOf(STRINGS[lang]));
    assert.deepEqual([...ko].filter((k) => !cur.has(k)), [], `${lang} 누락 키`);
    assert.deepEqual([...cur].filter((k) => !ko.has(k)), [], `${lang} 잉여 키`);
  }
});
