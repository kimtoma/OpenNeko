const BGM_PRESETS = [
  { id: 'lofi-coding', title: 'Lo-fi coding playlist', terms: ['lofi', 'coding', 'focus'] },
  { id: 'cafe-jazz', title: 'Cafe jazz work playlist', terms: ['cafe jazz', 'work', 'instrumental'] },
  { id: 'rainy-focus', title: 'Rainy focus playlist', terms: ['rain sounds', 'ambient', 'study'] },
  { id: 'city-pop-work', title: 'City pop work playlist', terms: ['city pop', 'work', 'upbeat'] },
  { id: 'piano-deep-work', title: 'Piano deep work playlist', terms: ['piano', 'deep work', 'instrumental'] },
  { id: 'synthwave-night', title: 'Synthwave night drive playlist', terms: ['synthwave', 'night drive', 'focus'] },
  { id: 'chillhop-desk', title: 'Chillhop desk playlist', terms: ['chillhop', 'desk work', 'beats'] },
  { id: 'game-ost-study', title: 'Game OST study playlist', terms: ['game ost', 'study', 'relaxing'] },
  { id: 'ambient-coding', title: 'Ambient coding playlist', terms: ['ambient', 'coding', 'no vocals'] },
  { id: 'k-indie-focus', title: 'K-indie focus playlist', terms: ['korean indie', 'focus', 'playlist'] },
];

const LANG_TERMS = {
  ko: ['BGM', '플레이리스트'],
  en: ['BGM', 'playlist'],
  ja: ['BGM', 'プレイリスト'],
  zh: ['BGM', '播放列表'],
};

const TIME_TERMS = {
  morning: { ko: '아침', en: 'morning', ja: '朝', zh: '早晨' },
  afternoon: { ko: '오후', en: 'afternoon', ja: '午後', zh: '下午' },
  evening: { ko: '저녁', en: 'evening', ja: '夕方', zh: '傍晚' },
  night: { ko: '밤', en: 'night', ja: '夜', zh: '夜晚' },
};

function dateKey(date = new Date()) {
  const d = date instanceof Date ? date : new Date(date);
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  return `${y}-${m}-${day}`;
}

function hashString(s) {
  let h = 2166136261;
  for (const ch of String(s)) {
    h ^= ch.charCodeAt(0);
    h = Math.imul(h, 16777619);
  }
  return h >>> 0;
}

function normalizePreference(input) {
  return String(input || '')
    .replace(/\s+/g, ' ')
    .replace(/[<>]/g, '')
    .trim()
    .slice(0, 80);
}

function timeBucket(date = new Date()) {
  const d = date instanceof Date ? date : new Date(date);
  const h = d.getHours();
  if (h < 11) return 'morning';
  if (h < 17) return 'afternoon';
  if (h < 21) return 'evening';
  return 'night';
}

function langTerms(lang) {
  return LANG_TERMS[lang] || LANG_TERMS.en;
}

function uniqueTerms(items) {
  const out = [];
  const seen = new Set();
  for (const raw of items) {
    const item = normalizePreference(raw);
    const key = item.toLowerCase();
    if (!item || seen.has(key)) continue;
    seen.add(key);
    out.push(item);
  }
  return out;
}

function buildBgmQuery({ preset, preference = '', lang = 'en', date = new Date() } = {}) {
  const bucket = timeBucket(date);
  const timeTerm = (TIME_TERMS[bucket] && (TIME_TERMS[bucket][lang] || TIME_TERMS[bucket].en)) || bucket;
  return uniqueTerms([
    preference,
    ...(preset && preset.terms ? preset.terms : []),
    timeTerm,
    ...langTerms(lang),
  ]).join(' ');
}

function buildYoutubeMusicSearchUrl(query) {
  return `https://music.youtube.com/search?q=${encodeURIComponent(query)}`;
}

function pickDailyBgm(date = new Date(), options = {}, presets = BGM_PRESETS) {
  if (Array.isArray(options)) {
    presets = options;
    options = {};
  }
  const list = presets && presets.length ? presets : BGM_PRESETS;
  const key = dateKey(date);
  const profile = options.profile && typeof options.profile === 'object' ? options.profile : {};
  const preference = normalizePreference(options.preference);
  const lang = options.lang || 'en';

  // Profile data personalizes only the deterministic pick. It is not sent in the
  // YouTube Music query, so birth date/name do not leak through the URL.
  const seed = [
    key,
    lang,
    preference,
    profile.name || '',
    profile.birthDate || '',
    profile.calendar || '',
  ].join('|');
  const preset = list[hashString(seed) % list.length];
  const query = buildBgmQuery({ preset, preference, lang, date });
  return {
    ...preset,
    dateKey: key,
    query,
    url: buildYoutubeMusicSearchUrl(query),
    service: 'YouTube Music',
    personalized: !!(preference || profile.name || profile.birthDate),
  };
}

module.exports = {
  BGM_PRESETS,
  buildBgmQuery,
  buildYoutubeMusicSearchUrl,
  dateKey,
  hashString,
  normalizePreference,
  pickDailyBgm,
  timeBucket,
};
