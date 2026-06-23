const { test } = require('node:test');
const assert = require('node:assert');
const { BUNDLED_SKINS, bundledSkinBase, mergeSkins, resolveSkin } = require('../src/renderer/skins');

test('BUNDLED_SKINS: 5종 + labelKey/swatch', () => {
  const ids = BUNDLED_SKINS.map((s) => s.id);
  assert.deepEqual(ids, ['white', 'black', 'orange', 'pink', 'calico']);
  for (const s of BUNDLED_SKINS) { assert.ok(s.labelKey.startsWith('skin.')); assert.match(s.swatch, /^#/); }
});
test('bundledSkinBase: white=루트, 그 외=하위폴더', () => {
  assert.equal(bundledSkinBase('white'), 'sprites/');
  assert.equal(bundledSkinBase('black'), 'sprites/black/');
});
test('mergeSkins: 번들+외부, 동일 id는 번들 우선', () => {
  const ext = [{ id: 'black', label: 'X', base: 'file:///x/' }, { id: 'xmas', label: 'Xmas', base: 'file:///e/' }];
  const merged = mergeSkins(BUNDLED_SKINS, ext);
  assert.equal(merged.find((s) => s.id === 'xmas').base, 'file:///e/');     // 외부 전용 포함
  assert.equal(merged.find((s) => s.id === 'black').base, 'sprites/black/'); // 번들 우선
});
test('resolveSkin: 목록에 있으면 그 id, 없으면 white', () => {
  const all = mergeSkins(BUNDLED_SKINS, []);
  assert.equal(resolveSkin('orange', all), 'orange');
  assert.equal(resolveSkin('nope', all), 'white');
  assert.equal(resolveSkin(null, all), 'white');
});
