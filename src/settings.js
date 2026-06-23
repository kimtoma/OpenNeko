const fs = require('node:fs');
const path = require('node:path');

function sanitizeNeighbor(n) {
  const out = { enabled: true, displayName: '' };
  if (n && typeof n === 'object') {
    if (typeof n.enabled === 'boolean') out.enabled = n.enabled;
    if (typeof n.displayName === 'string') out.displayName = n.displayName.slice(0, 64);
  }
  return out;
}

// 의존성(dir, safeStorage)을 주입받아 테스트 가능하게. 메인에서 app.getPath/electron.safeStorage로 생성.
function makeStore({ dir, safeStorage }) {
  const file = path.join(dir, 'settings.json');

  function load() {
    let raw;
    try { raw = JSON.parse(fs.readFileSync(file, 'utf8')); }
    catch { return { provider: null, apiKey: '', sound: { enabled: true }, skin: 'white', onboarded: false, neighbor: { enabled: true, displayName: '' }, peerId: '', catName: '', webSearch: false }; }
    let apiKey = '';
    if (raw.secret && safeStorage && safeStorage.isEncryptionAvailable()) {
      try { apiKey = safeStorage.decryptString(Buffer.from(raw.secret, 'base64')); } catch { apiKey = ''; }
    }
    return {
      provider: raw.provider || null,
      apiKey,
      sound: raw.sound && typeof raw.sound.enabled === 'boolean' ? raw.sound : { enabled: true },
      lang: raw.lang || null,
      skin: raw.skin || 'white',
      onboarded: !!raw.onboarded,
      disabledSkills: Array.isArray(raw.disabledSkills) ? raw.disabledSkills : [],
      webSearch: raw.webSearch === true,
      profile: (raw.profile && typeof raw.profile === 'object') ? raw.profile : {},
      neighbor: sanitizeNeighbor(raw.neighbor),
      peerId: typeof raw.peerId === 'string' ? raw.peerId : '',
      catName: (typeof raw.catName === 'string' && raw.catName)
        ? raw.catName
        : ((raw.neighbor && typeof raw.neighbor.displayName === 'string') ? raw.neighbor.displayName : ''),
    };
  }

  function save({ provider, apiKey, sound, lang, skin, onboarded, disabledSkills, webSearch, profile, neighbor, peerId, catName }) {
    const out = { provider };
    if (apiKey) {
      if (!safeStorage || !safeStorage.isEncryptionAvailable()) throw new Error('safeStorage 사용 불가 — 키를 저장할 수 없다냥');
      out.secret = safeStorage.encryptString(apiKey).toString('base64');
    }
    out.sound = sound && typeof sound.enabled === 'boolean' ? sound : { enabled: true };
    if (lang != null) out.lang = lang;
    if (skin != null) out.skin = skin;
    if (onboarded != null) out.onboarded = !!onboarded;
    if (Array.isArray(disabledSkills)) out.disabledSkills = disabledSkills;
    if (webSearch != null) out.webSearch = !!webSearch;
    if (profile != null && typeof profile === 'object') out.profile = profile;
    if (neighbor != null) out.neighbor = sanitizeNeighbor(neighbor);
    if (peerId != null) out.peerId = String(peerId);
    if (catName != null) out.catName = String(catName).slice(0, 64);
    fs.mkdirSync(dir, { recursive: true });
    fs.writeFileSync(file, JSON.stringify(out, null, 2));
  }

  return { load, save, file };
}
module.exports = { makeStore };
