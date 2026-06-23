const BUNDLED_SKINS = [
  { id: 'white',  labelKey: 'skin.white',  swatch: '#f2f4f8' },
  { id: 'black',  labelKey: 'skin.black',  swatch: '#2b2e3a' },
  { id: 'orange', labelKey: 'skin.orange', swatch: '#e8923c' },
  { id: 'pink',   labelKey: 'skin.pink',   swatch: '#f3a6c0' },
  { id: 'calico', labelKey: 'skin.calico', swatch: '#e6b15a' },
];
const BUNDLED_IDS = new Set(BUNDLED_SKINS.map((s) => s.id));
function bundledSkinBase(id) { return id === 'white' ? 'sprites/' : `sprites/${id}/`; }
function skinSpriteBase(id) {
  if (!BUNDLED_IDS.has(id) || id === 'white') return 'sprites/';
  return `sprites/${id}/`;
}
// bundled: [{id,labelKey,swatch}], external: [{id,label,base}] → 통합 [{id,labelKey?,label?,swatch?,base}]
function mergeSkins(bundled, external = []) {
  const out = bundled.map((s) => ({ ...s, base: bundledSkinBase(s.id) }));
  const have = new Set(out.map((s) => s.id));
  // 외부 swatch는 색 코드만 허용(외부 팩이 CSS를 끼워넣지 못하게) — 아니면 회색.
  const safeSwatch = (c) => (/^#[0-9a-fA-F]{3,8}$/.test(c) ? c : '#ccc');
  for (const e of external) if (!have.has(e.id)) out.push({ id: e.id, label: e.label || e.id, swatch: safeSwatch(e.swatch), base: e.base });
  return out;
}
function resolveSkin(savedId, allSkins) {
  return allSkins.some((s) => s.id === savedId) ? savedId : 'white';
}
module.exports = { BUNDLED_SKINS, bundledSkinBase, skinSpriteBase, mergeSkins, resolveSkin };
