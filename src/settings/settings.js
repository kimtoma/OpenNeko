const { categorizeProviders, friendlyLabel } = require('./cards');
const { createI18n } = require('../i18n');

const $ = (id) => document.getElementById(id);
const esc = (s) => String(s).replace(/[&<>"']/g, (c) => (
  { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));

// 콘텐츠 높이에 맞춰 창을 리사이즈 — 세로 스크롤이 안 생기게. DOM 변경 후 호출.
function fit() {
  requestAnimationFrame(() => window.settings.resize(Math.ceil(document.documentElement.scrollHeight)));
}

const ICONS = {
  'chatgpt-oauth': 'icons/openai.svg',
  'claude-oauth': 'icons/claude.svg',
  'gemini-oauth': 'icons/gemini.svg',
  ollama: 'icons/ollama.svg',
  'local-openai': 'icons/local.svg',
  gemini: 'icons/gemini.svg',
  claude: 'icons/claude.svg',
  custom: 'icons/custom.svg',
};

// 웹 검색을 지원하는 preset id 목록
const WEBSEARCH_SUPPORTED = new Set();

let PRESETS = [];
let cur = { presetId: 'chatgpt-oauth', provider: null, hasKey: false, sound: { enabled: true }, resolvedLang: 'en', skin: 'white', onboarding: false, webSearch: false };
let detected = [];
let allSkins = [];
let presetById = {};
let t = createI18n('en').t; // 초기값, init에서 cur.resolvedLang으로 갱신
let statusTimer = null;

function status(msg) {
  const el = $('status');
  if (!el) return;
  clearTimeout(statusTimer);
  el.textContent = msg || '';
  el.classList.toggle('show', !!msg);
  if (msg) {
    statusTimer = setTimeout(() => {
      el.textContent = '';
      el.classList.remove('show');
    }, 4200);
  }
}

function defaultSubForPreset(presetId) {
  const p = presetById[presetId] || {};
  if (p.cliBin) return t('settings.subOAuth');
  if (p.local) return t('settings.subLocal');
  return t('settings.subConnected');
}

function sourceLabel(source) {
  const labels = {
    oauth: 'OAuth',
    local: 'Local',
    env: 'ENV',
    saved: 'Saved',
  };
  return labels[source] || source;
}

function readySubtitle(card) {
  if (card.recommended) return t('settings.subRecommendedOAuth');
  if (card.subtitle && card.subtitle.startsWith('Ready')) return t('settings.subReady');
  return card.subtitle || defaultSubForPreset(card.presetId);
}

function cardMeta(card) {
  const tags = [];
  if (card.source) tags.push(`<span class="tag source">${esc(sourceLabel(card.source))}</span>`);
  if (card.models && card.models.length) {
    tags.push(`<span class="tag model">${esc(card.models.slice(0, 2).join(', '))}</span>`);
  }
  return tags.length ? `<div class="meta">${tags.join('')}</div>` : '';
}

function providerIconImg(presetId, label) {
  const src = ICONS[presetId] || 'icons/custom.svg';
  return `<img class="provider-icon" src="${esc(src)}" alt="${esc(label || presetId)}">`;
}

function providerIcon(presetId, label) {
  return `<span class="ico">${providerIconImg(presetId, label)}</span>`;
}

// --- 첫 실행 환영 배너 -------------------------------------------------------------
function renderOnboardBanner() {
  const banner = $('onboard-banner');
  if (!banner) return;
  if (cur.onboarding) {
    banner.style.display = 'block';
    banner.textContent = t('onboard.welcome');
  } else {
    banner.style.display = 'none';
  }
}

// --- 카드 목록 ---------------------------------------------------------------
function renderCards() {
  const { ready, connect } = categorizeProviders({ presets: PRESETS, detected, currentPresetId: cur.presetId });
  const box = $('cards');
  box.innerHTML = '';
  const readyIds = new Set(ready.map((c) => c.presetId));

  // 현재 쓰는 AI가 ready에 없으면(직접 입력형/로그인 미감지 등) 맨 위에 '사용 중' 카드로 표시 —
  // 안 그러면 일반 유저가 보기에 아무것도 선택 안 된 것처럼 보인다.
  if (!readyIds.has(cur.presetId) && presetById[cur.presetId]) {
    const label = friendlyLabel(cur.presetId, presetById[cur.presetId].label, t);
    const parts = cur.provider ? [cur.provider.model, cur.provider.baseURL].filter(Boolean) : [];
    const sub = parts.length ? esc(parts.join(' · ')) : defaultSubForPreset(cur.presetId);
    const card = connect.find((c) => c.presetId === cur.presetId);
    const el = document.createElement('div');
    el.className = 'card current';
    el.innerHTML =
      providerIcon(cur.presetId, label) +
      `<div class="body"><div class="title">${esc(label)}</div><div class="sub">${sub}</div></div>` +
      `<span class="badge">${esc(t('settings.inUse'))}</span>`;
    if (card) { el.style.cursor = 'pointer'; el.title = t('settings.pick'); el.onclick = () => openConnectFor(card); }
    box.appendChild(el);
  }

  for (const c of ready) {
    const isCur = c.presetId === cur.presetId;
    const el = document.createElement('div');
    el.className = 'card' + (isCur ? ' current' : '');
    const subtitle = readySubtitle(c);
    const label = friendlyLabel(c.presetId, c.label, t);
    el.innerHTML =
      providerIcon(c.presetId, label) +
      `<div class="body"><div class="title">${esc(label)}${c.recommended ? ` <span class="tag recommended">${esc(t('settings.recommended'))}</span>` : ''}</div>` +
      `<div class="sub">${esc(subtitle)}</div>${cardMeta(c)}</div>` +
      (isCur ? `<span class="badge">${esc(t('settings.inUse'))}</span>` : `<span class="pick">${esc(t('settings.pick'))}</span>`);
    if (!isCur) el.onclick = () => selectReady(c.presetId, label, c);
    box.appendChild(el);
  }

  // "다른 AI 연결하기" 카드
  const add = document.createElement('div');
  add.className = 'card add';
  add.textContent = t('settings.addOther');
  add.onclick = () => toggleConnect(connect);
  box.appendChild(add);
  fit();
}

function renderSkins(targetId = 'skins') {
  const box = $(targetId);
  if (!box) return;
  box.innerHTML = '';

  // 모든 스킨은 무료로 선택 가능. 첫 실행(환영) 때 선택하면 온보딩 완료로 표시.
  // 미리보기는 해당 스킨의 idle_0 스프라이트. 이미지 로드 실패 시 색 점으로 폴백.
  for (const skin of allSkins) {
    const label = skin.labelKey ? t(skin.labelKey) : (skin.label || skin.id);
    const btn = document.createElement('button');
    btn.className = 'skin-tile' + (skin.id === cur.skin ? ' selected' : '');
    const swatch = esc(skin.swatch || '#ccc');
    const thumb = skin.preview
      ? `<span class="skin-thumb"><img src="${esc(skin.preview)}" alt="${esc(label)}" ` +
        `onerror="this.style.display='none';this.parentNode.style.background='${swatch}'"></span>`
      : `<span class="skin-thumb" style="background:${swatch}"></span>`;
    btn.innerHTML = thumb + `<span class="skin-name">${esc(label)}</span>`;
    btn.onclick = async () => {
      // 온보딩 중에도 스킨은 즉시 적용만 — 온보딩 완료는 위저드 마지막 스텝에서.
      await window.settings.setSkin({ id: skin.id });
      cur.skin = skin.id;
      renderSkins(targetId);
    };
    box.appendChild(btn);
  }
  fit();
}

async function selectReady(presetId, label, detectedCard) {
  status(t('settings.changing'));
  const preset = presetById[presetId] || {};
  const fields = {};
  if ((preset.fields || []).includes('model') && detectedCard && (detectedCard.model || (detectedCard.models && detectedCard.models[0]))) {
    fields.model = detectedCard.model || detectedCard.models[0];
  }
  const r = await window.settings.save({ presetId, fields });
  if (r.ok) { await refresh(); status(t('settings.nowAnswers', { name: label })); }
  else status('저장 실패: ' + r.error);
}

// --- 다른 AI 연결 (키/주소 입력) ---------------------------------------------
function renderConnect(connect, selected) {
  const wrap = $('connect');
  wrap.classList.add('show');
  wrap.innerHTML =
    `<div class="connect-head"><div class="connect-title">${esc(t('settings.whichService'))}</div>` +
    `<button class="icon-btn" id="connect-close" title="${esc(t('settings.cancel'))}" aria-label="${esc(t('settings.cancel'))}">&times;</button></div>` +
    `<div class="svc"></div><div id="connect-form"></div>`;
  $('connect-close').onclick = () => { wrap.classList.remove('show'); wrap.innerHTML = ''; fit(); };
  const svc = wrap.querySelector('.svc');
  for (const c of connect) {
    const b = document.createElement('button');
    const label = friendlyLabel(c.presetId, c.label, t);
    b.innerHTML = `<span class="svc-ico">${providerIconImg(c.presetId, label)}</span><span>${esc(label)}</span>`;
    if (selected && c.presetId === selected.presetId) b.classList.add('sel');
    b.onclick = () => {
      svc.querySelectorAll('button').forEach((x) => x.classList.remove('sel'));
      b.classList.add('sel');
      renderConnectForm(c);
    };
    svc.appendChild(b);
  }
  if (selected) renderConnectForm(selected);
  fit();
}

function toggleConnect(connect) {
  const wrap = $('connect');
  if (wrap.classList.contains('show')) { wrap.classList.remove('show'); wrap.innerHTML = ''; fit(); return; }
  renderConnect(connect, null);
}

// '사용 중' connect 카드를 눌렀을 때 — 연결창을 열고 그 서비스 폼을 바로 띄워 수정.
function openConnectFor(card) {
  const { connect } = categorizeProviders({ presets: PRESETS, detected, currentPresetId: cur.presetId });
  renderConnect(connect, card);
}

function renderConnectForm(card) {
  const form = $('connect-form');
  const p = presetById[card.presetId] || {};
  const isCur = card.presetId === cur.presetId;
  const FIELD_LABEL = { apiKey: t('settings.fieldApiKey'), baseURL: t('settings.fieldBaseURL'), model: t('settings.fieldModel') };
  const FIELD_HINT = {
    apiKey: t('settings.hintApiKey'),
    baseURL: t('settings.hintBaseURL'),
    model: t('settings.hintModel'),
  };
  let html = '';
  if (p.note) html += `<div class="hint connect-note">${esc(p.note)}</div>`;
  for (const f of card.fields) {
    let val = '';
    if (f === 'apiKey') { if (isCur && cur.hasKey) val = '••••'; }
    else if (isCur && cur.provider && cur.provider[f] != null) val = cur.provider[f];
    else if (p.defaults && p.defaults[f]) val = p.defaults[f];
    const type = f === 'apiKey' ? 'password' : 'text';
    html += `<div class="field"><label>${esc(FIELD_LABEL[f] || f)}</label>` +
      `<input id="cf_${esc(f)}" type="${type}" value="${esc(val)}">` +
      `<div class="hint">${esc(FIELD_HINT[f] || '')}</div></div>`;
  }
  html += `<div class="actions"><button class="primary" id="cf-go">${esc(t('settings.connectGo'))}</button>` +
    `<button class="ghost" id="cf-cancel">${esc(t('settings.cancel'))}</button></div>`;
  form.innerHTML = html;
  $('cf-go').onclick = () => connectSave(card);
  $('cf-cancel').onclick = () => { $('connect').classList.remove('show'); $('connect').innerHTML = ''; fit(); };
  fit();
}

function collectFields(card) {
  const fields = {};
  for (const f of card.fields) {
    const v = ($('cf_' + f).value || '').trim();
    if (f === 'apiKey') { if (v && v !== '••••') fields.apiKey = v; } // ••••/빈칸이면 기존 키 유지
    else if (v) fields[f] = v; // 빈 baseURL/model은 안 보냄 → 프리셋 기본값이 적용되게(기본값 덮어쓰기 방지)
  }
  return fields;
}

async function connectSave(card) {
  const fields = collectFields(card);
  const keepsKey = card.presetId === cur.presetId && cur.hasKey;
  const p = presetById[card.presetId] || {};
  if (card.fields.includes('baseURL') && !fields.baseURL) { status(t('settings.needUrl')); return; }
  if (p.requiresApiKey && card.fields.includes('apiKey') && !fields.apiKey && !keepsKey) { status(t('settings.needKey')); return; }
  status(t('settings.checking'));
  const r = await window.settings.test({ presetId: card.presetId, fields });
  if (!r.ok) { status('❌ ' + friendlyError(r.error)); return; }
  const s = await window.settings.save({ presetId: card.presetId, fields });
  if (!s.ok) { status('저장 실패: ' + s.error); return; }
  $('connect').classList.remove('show'); $('connect').innerHTML = '';
  await refresh();
  status(t('settings.connected', { name: friendlyLabel(card.presetId, card.label, t) }));
}

function friendlyError(err) {
  const e = String(err || '');
  if (/키|AUTH|401|403/.test(e)) return t('settings.errAuth');
  if (/모델|엔드포인트|NOTFOUND|404/.test(e)) return t('settings.errNotFound');
  if (/연결|ECONNREFUSED|fetch|ENOTFOUND|서버/.test(e)) return t('settings.errConn');
  return t('settings.errGeneric');
}

// --- 고급: 현재 연결 상태 확인 ------------------------------------------------
async function testCurrent() {
  status(t('settings.checking'));
  const fields = {};
  if (cur.provider) {
    if (cur.provider.baseURL) fields.baseURL = cur.provider.baseURL;
    if (cur.provider.model) fields.model = cur.provider.model;
  }
  const r = await window.settings.test({ presetId: cur.presetId, fields });
  status(r.ok ? t('settings.testOk', { text: r.text || '' }) : '❌ ' + friendlyError(r.error));
}

// --- 초기화 ------------------------------------------------------------------
// --- 스킬 섹션 ---------------------------------------------------------------
async function renderSkillsSection() {
  const sec = $('skills-section');
  if (!sec) return;
  let skills = [];
  try { skills = await window.settings.skillsList(); } catch { /* skills 불가 */ }
  const inputBadge = (input) => {
    if (input === 'clipboard') return t('skills.inputClipboard');
    if (input === 'none') return t('skills.inputNone');
    return t('skills.inputPrompt');
  };
  let html = `<div class="section-head">` +
    `<span>${esc(t('skills.section'))}</span>` +
    `<button class="skills-folder-btn" id="skills-folder-btn">${esc(t('skills.openFolder'))}</button>` +
    `</div>`;
  if (skills.length === 0) {
    html += `<div class="section-body panel"><div class="empty-state">${esc(t('skills.empty'))}</div></div>`;
  } else {
    html += `<div class="section-body panel">`;
    for (const s of skills) {
      const togId = `skill-tog-${esc(s.id)}`;
      html += `<div class="skill-row">` +
        `<div class="skill-info">` +
        `<div class="skill-name">${esc(s.name)}</div>` +
        (s.description ? `<div class="skill-desc">${esc(s.description)}</div>` : '') +
        `</div>` +
        `<span class="skill-badge">${esc(inputBadge(s.input))}</span>` +
        `<label class="switch small-switch skill-toggle-label">` +
        `<input type="checkbox" id="${togId}" data-id="${esc(s.id)}"${s.enabled ? ' checked' : ''}>` +
        `<span class="slider"></span>` +
        `</label>` +
        `</div>`;
    }
    html += `</div>`;
  }
  sec.innerHTML = html;
  // 폴더 열기 버튼
  const folderBtn = $('skills-folder-btn');
  if (folderBtn) folderBtn.onclick = () => window.settings.openSkillsFolder();
  // 토글 이벤트
  for (const s of skills) {
    const tog = $(`skill-tog-${s.id}`);
    if (tog) {
      tog.addEventListener('change', async () => {
        await window.settings.setSkillEnabled({ id: s.id, enabled: tog.checked });
      });
    }
  }
  fit();
}

function updateWebSearchUI() {
  const wsEl = $('websearch-enabled');
  if (wsEl) wsEl.checked = cur.webSearch !== false;
  const noteEl = $('websearch-note');
  if (noteEl) {
    noteEl.textContent = WEBSEARCH_SUPPORTED.has(cur.presetId) ? '' : t('websearch.unsupported');
  }
}

async function refresh() {
  cur = await window.settings.get();
  if (!cur.sound) cur.sound = { enabled: true };
  if (!cur.skin) cur.skin = 'white';
  if (cur.webSearch == null) cur.webSearch = true;
  if (!cur.profile) cur.profile = {};
  renderOnboardBanner();
  renderCards();
  renderSkins();
  await renderSkillsSection();
  renderProfileSection();
  const soundEl = $('sound-enabled');
  if (soundEl) soundEl.checked = cur.sound.enabled !== false;
  // 고양이 이름 동기화
  const cn = $('cat-name'); if (cn) cn.value = cur.catName || '';
  // 이웃 고양이 동기화
  const nb = cur.neighbor || { enabled: true, displayName: '' };
  const ne = $('neighbor-enabled'); if (ne) ne.checked = nb.enabled !== false;
  // 웹 검색 토글 동기화
  updateWebSearchUI();
  // 언어 선택 드롭다운 동기화
  const langEl = $('lang');
  if (langEl) langEl.value = cur.resolvedLang || 'en';
  updateSummaries();
}

// ===== 온보딩 위저드 =========================================================
const WIZ_STEPS = ['welcome', 'skin', 'name', 'perms', 'backend', 'cheats'];
let wizIdx = 0;
let wizPermTimer = null;

function stopPermPoll() { if (wizPermTimer) { clearInterval(wizPermTimer); wizPermTimer = null; } }

function startWizard() {
  document.querySelectorAll('.page').forEach((p) => p.classList.remove('active'));
  $('page-wizard').classList.add('active');
  wizIdx = 0;
  renderWizard();
}

function renderWizard() {
  stopPermPoll();
  const step = WIZ_STEPS[wizIdx];
  $('wiz-dots').innerHTML = WIZ_STEPS.map((_s, i) => `<span class="wiz-dot${i === wizIdx ? ' on' : ''}"></span>`).join('');
  const body = $('wiz-body');
  body.innerHTML = '';
  status('');
  if (step === 'welcome') renderWizWelcome(body);
  else if (step === 'skin') renderWizSkin(body);
  else if (step === 'name') renderWizName(body);
  else if (step === 'perms') renderWizPerms(body);
  else if (step === 'backend') renderWizBackend(body);
  else if (step === 'cheats') renderWizCheats(body);
  renderWizNav();
  fit();
}

function renderWizNav() {
  const nav = $('wiz-nav');
  const step = WIZ_STEPS[wizIdx];
  const isFirst = wizIdx === 0;
  const isLast = wizIdx === WIZ_STEPS.length - 1;
  let html = '';
  if (!isFirst) html += `<button class="ghost" id="wiz-back">${esc(t('onboard.back'))}</button>`;
  html += '<span style="flex:1"></span>';
  if (step === 'perms' || step === 'backend') html += `<button class="ghost" id="wiz-skip">${esc(t('onboard.skip'))}</button>`;
  const nextLabel = isLast ? t('onboard.finish') : (isFirst ? t('onboard.start') : t('onboard.next'));
  html += `<button class="primary" id="wiz-next">${esc(nextLabel)}</button>`;
  nav.innerHTML = html;
  if ($('wiz-back')) $('wiz-back').onclick = () => { wizIdx = Math.max(0, wizIdx - 1); renderWizard(); };
  if ($('wiz-skip')) $('wiz-skip').onclick = nextWiz;
  $('wiz-next').onclick = () => (isLast ? finishWizard() : nextWiz());
}

function nextWiz() { wizIdx = Math.min(WIZ_STEPS.length - 1, wizIdx + 1); renderWizard(); }

async function finishWizard() {
  stopPermPoll();
  try { await window.settings.onboardComplete(); } catch { /* ignore */ }
  cur.onboarding = false;
  $('page-wizard').classList.remove('active');
  await refresh();
  showPage('page-home');
}

function renderWizWelcome(body) {
  body.innerHTML =
    '<div class="wiz-hero">🐾</div>' +
    `<h2 class="wiz-title">${esc(t('onboard.s1Title'))}</h2>` +
    `<p class="wiz-text">${esc(t('onboard.s1Body'))}</p>`;
}

function renderWizSkin(body) {
  body.innerHTML =
    `<h2 class="wiz-title">${esc(t('onboard.s2Title'))}</h2>` +
    `<p class="wiz-text">${esc(t('onboard.s2Body'))}</p>` +
    '<div id="wiz-skins"></div>';
  renderSkins('wiz-skins');
}

function renderWizName(body) {
  body.innerHTML =
    `<h2 class="wiz-title">${esc(t('onboard.nameTitle'))}</h2>` +
    `<p class="wiz-text">${esc(t('onboard.nameBody'))}</p>` +
    `<div class="field"><input type="text" id="wiz-cat-name" maxlength="64" placeholder="${esc(t('onboard.namePlaceholder'))}"></div>`;
  const el = $('wiz-cat-name');
  if (el) {
    el.value = cur.catName || '';
    el.onchange = () => { cur.catName = el.value; window.settings.setCatName({ name: el.value }); };
  }
}

async function renderWizPerms(body) {
  let st = { platform: 'darwin', accessibility: false, inputSeen: false };
  try { st = await window.settings.permStatus(); } catch { /* ignore */ }
  if (st.platform !== 'darwin') {
    body.innerHTML =
      `<h2 class="wiz-title">${esc(t('onboard.s3Title'))}</h2>` +
      `<p class="wiz-text">${esc(t('onboard.s3BodyWin'))}</p>`;
    return;
  }
  const mark = (ok) => (ok ? '✓' : '…');
  body.innerHTML =
    `<h2 class="wiz-title">${esc(t('onboard.s3Title'))}</h2>` +
    `<p class="wiz-text">${esc(t('onboard.s3BodyMac'))}</p>` +
    `<div class="wiz-perm"><button class="ghost" id="wiz-perm-a">${esc(t('onboard.s3OpenAccess'))}</button><span class="wiz-status" id="wiz-st-a">${mark(st.accessibility)}</span></div>` +
    `<div class="wiz-perm"><button class="ghost" id="wiz-perm-i">${esc(t('onboard.s3OpenInput'))}</button><span class="wiz-status" id="wiz-st-i">${mark(st.inputSeen)}</span></div>` +
    `<p class="hint">${esc(t('onboard.s3Note'))}</p>`;
  $('wiz-perm-a').onclick = () => window.settings.openPerms({ which: 'accessibility' });
  $('wiz-perm-i').onclick = () => window.settings.openPerms({ which: 'input' });
  // 허용 후 돌아오면 ✓로 바뀌게 가볍게 폴링 (이 스텝에 있는 동안만)
  stopPermPoll();
  wizPermTimer = setInterval(async () => {
    if (WIZ_STEPS[wizIdx] !== 'perms') { stopPermPoll(); return; }
    try {
      const s2 = await window.settings.permStatus();
      const a = $('wiz-st-a'); const i = $('wiz-st-i');
      if (a) a.textContent = mark(s2.accessibility);
      if (i) i.textContent = mark(s2.inputSeen);
    } catch { /* ignore */ }
  }, 2500);
}

async function renderWizBackend(body) {
  try { detected = await window.settings.detect(); } catch { /* keep prior */ }
  const { ready } = categorizeProviders({ presets: PRESETS, detected, currentPresetId: cur.presetId });
  body.innerHTML =
    `<h2 class="wiz-title">${esc(t('onboard.s4Title'))}</h2>` +
    `<p class="wiz-text">${esc(t('onboard.s4Body'))}</p>` +
    '<div id="wiz-cards"></div>';
  const box = $('wiz-cards');
  for (const c of ready) {
    const isCur = c.presetId === cur.presetId;
    const el = document.createElement('div');
    el.className = 'card' + (isCur ? ' current' : '');
    const subtitle = readySubtitle(c);
    const label = friendlyLabel(c.presetId, c.label, t);
    el.innerHTML =
      providerIcon(c.presetId, label) +
      `<div class="body"><div class="title">${esc(label)}</div>` +
      `<div class="sub">${esc(subtitle)}</div>${cardMeta(c)}</div>` +
      (isCur ? `<span class="badge">${esc(t('settings.inUse'))}</span>` : `<span class="pick">${esc(t('onboard.s4Use'))}</span>`);
    if (!isCur) el.onclick = async () => { await selectReady(c.presetId, label, c); renderWizBackend(body); };
    box.appendChild(el);
  }
  if (!ready.length) {
    const none = document.createElement('p');
    none.className = 'hint';
    none.textContent = t('onboard.s4None');
    box.appendChild(none);
  }
  const other = document.createElement('div');
  other.className = 'card add';
  other.textContent = t('onboard.s4Other');
  other.onclick = async () => {
    await finishWizard();
    const { connect } = categorizeProviders({ presets: PRESETS, detected, currentPresetId: cur.presetId });
    renderConnect(connect, null);
    const aiSection = $('section-ai');
    if (aiSection) aiSection.scrollIntoView({ block: 'start' });
  };
  box.appendChild(other);
  fit();
}

function renderWizCheats(body) {
  body.innerHTML =
    `<h2 class="wiz-title">${esc(t('onboard.s5Title'))}</h2>` +
    '<ul class="wiz-tips">' +
    `<li>🖱️ ${esc(t('onboard.s5Click'))}</li>` +
    `<li>✊ ${esc(t('onboard.s5Drag'))}</li>` +
    `<li>🖱️ ${esc(t('onboard.s5Right'))}</li>` +
    `<li>⌨️ ${esc(t('onboard.s5Slash'))}</li>` +
    '</ul>';
}

async function init() {
  PRESETS = await window.settings.presets();
  presetById = Object.fromEntries(PRESETS.map((p) => [p.id, p]));
  try { detected = await window.settings.detect(); } catch { detected = []; }
  try { allSkins = await window.settings.skinsList(); } catch { allSkins = []; }
  cur = await window.settings.get();
  if (!cur.sound) cur.sound = { enabled: true };
  if (!cur.skin) cur.skin = 'white';

  // i18n 초기화 — resolvedLang 기준
  const i18nObj = createI18n(cur.resolvedLang || 'en');
  t = i18nObj.t;

  // 정적 텍스트 업데이트
  applyStaticText();

  await refresh();

  const soundEl = $('sound-enabled');
  if (soundEl) soundEl.addEventListener('change', () => window.settings.setSound({ enabled: soundEl.checked }));

  const cn = $('cat-name');
  if (cn) cn.onchange = () => {
    cur.catName = cn.value;
    updateSummaries();
    window.settings.setCatName({ name: cn.value });
  };

  const ne = $('neighbor-enabled');
  if (ne) ne.onchange = () => window.settings.setNeighbor({ enabled: ne.checked });

  const wsEl = $('websearch-enabled');
  if (wsEl) wsEl.addEventListener('change', async () => {
    await window.settings.setWebSearch({ enabled: wsEl.checked });
    cur.webSearch = wsEl.checked;
    updateWebSearchUI();
  });

  const langEl = $('lang');
  if (langEl) {
    langEl.value = cur.resolvedLang || 'en';
    langEl.addEventListener('change', async () => {
      const lang = langEl.value;
      await window.settings.setLang({ lang });
      // 언어가 바뀌었으므로 설정창 전체 다시 렌더
      const i18nNew = createI18n(lang);
      t = i18nNew.t;
      applyStaticText();
      // 열려있던 연결 패널은 옛 언어 문자열이 남으므로 닫는다(다시 열면 새 언어로 렌더)
      const connectWrap = $('connect');
      if (connectWrap) { connectWrap.classList.remove('show'); connectWrap.innerHTML = ''; }
      await refresh();
      fit();
    });
  }

  const advTest = $('adv-test');
  if (advTest) advTest.onclick = testCurrent;
  const rerun = $('rerun-onboard');
  if (rerun) rerun.onclick = () => startWizard();
  const home = $('home');
  if (home) home.onclick = (e) => { e.preventDefault(); window.settings.openExternal('https://kimtoma.com'); };
  const advanced = $('advanced');
  if (advanced) advanced.addEventListener('toggle', fit);
  initProfileSection();
  initNav();
  // 첫 실행이면 온보딩 위저드, 아니면 홈
  if (cur.onboarding) startWizard(); else showPage('page-home');
  fit();
}

// --- 프로필 섹션 ---------------------------------------------------------------
function renderProfileSection() {
  // 레이블 갱신 (언어 변경 시 재호출)
  const nameLabel = $('profile-name-label');
  if (nameLabel) nameLabel.textContent = t('profile.name');
  const bdLabel = $('profile-birthdate-label');
  if (bdLabel) bdLabel.textContent = t('profile.birthDate');
  const btLabel = $('profile-birthtime-label');
  if (btLabel) btLabel.textContent = t('profile.birthTime');
  const calLabel = $('profile-calendar-label');
  if (calLabel) calLabel.textContent = t('profile.calendar');
  const solarOpt = $('profile-solar-opt');
  if (solarOpt) solarOpt.textContent = t('profile.solar');
  const lunarOpt = $('profile-lunar-opt');
  if (lunarOpt) lunarOpt.textContent = t('profile.lunar');
  const saveBtn = $('profile-save');
  if (saveBtn) saveBtn.textContent = t('profile.save');
  const privacyEl = $('profile-privacy');
  if (privacyEl) privacyEl.textContent = t('profile.privacy');
  // 섹션 헤더
  const sec = $('profile-section');
  if (sec) {
    const head = sec.querySelector('.section-head');
    if (head) head.textContent = t('profile.section');
  }

  // 현재 프로필 값 채우기
  const profile = cur.profile || {};
  const nameEl = $('profile-name');
  if (nameEl && !nameEl.dataset.dirty) nameEl.value = profile.name || '';
  const bdEl = $('profile-birthdate');
  if (bdEl && !bdEl.dataset.dirty) bdEl.value = profile.birthDate || '';
  const btEl = $('profile-birthtime');
  if (btEl && !btEl.dataset.dirty) btEl.value = profile.birthTime || '';
  const calEl = $('profile-calendar');
  if (calEl && !calEl.dataset.dirty) calEl.value = profile.calendar || 'solar';
}

function initProfileSection() {
  const saveBtn = $('profile-save');
  if (!saveBtn) return;
  saveBtn.onclick = async () => {
    const name = ($('profile-name').value || '').trim();
    const birthDate = ($('profile-birthdate').value || '').trim();
    const birthTime = ($('profile-birthtime').value || '').trim();
    const calendar = ($('profile-calendar').value || 'solar');
    const profile = { name, birthDate, birthTime, calendar };
    await window.settings.setProfile({ profile });
    cur.profile = profile;
    // 저장됨 메시지 잠깐 표시
    const msgEl = $('profile-saved-msg');
    if (msgEl) {
      msgEl.textContent = t('profile.saved');
      msgEl.style.display = '';
      setTimeout(() => { if (msgEl) msgEl.style.display = 'none'; }, 2000);
    }
    // dirty 플래그 제거 (저장 후 refresh 시 값 덮어쓰지 않게)
    [$('profile-name'), $('profile-birthdate'), $('profile-birthtime'), $('profile-calendar')]
      .forEach((el) => { if (el) delete el.dataset.dirty; });
  };
  // 사용자가 필드를 건드리면 dirty 표시 (refresh 시 덮어쓰기 방지)
  [$('profile-name'), $('profile-birthdate'), $('profile-birthtime'), $('profile-calendar')]
    .forEach((el) => {
      if (el) el.addEventListener('input', () => { el.dataset.dirty = '1'; });
      if (el) el.addEventListener('change', () => { el.dataset.dirty = '1'; });
    });
}

function setText(id, str) { const el = $(id); if (el) el.textContent = str; }

function applyStaticText() {
  setText('home-title', t('settings.navHome'));
  setText('ai-title', t('settings.title'));
  setText('ai-sub', t('settings.navAiSub'));
  setText('appearance-title', t('settings.navAppearance'));
  setText('appearance-sub', t('settings.navAppearanceSub'));
  setText('profile-title', t('profile.section'));
  setText('profile-sub', t('settings.navProfileSub'));
  setText('general-title', t('settings.navGeneral'));
  setText('general-sub', t('settings.navGeneralSub'));
  setText('adv-test', t('settings.testCurrent'));
  setText('sound-label', t('settings.soundLabel'));
  setText('sound-on-label', t('settings.soundOn'));
  setText('websearch-on-label', t('settings.soundOn'));
  setText('lang-label', t('settings.langLabel'));
  setText('rerun-onboard', t('onboard.start'));
  setText('cat-name-label', t('settings.catNameLabel'));
  const cnEl = $('cat-name'); if (cnEl) cnEl.placeholder = t('settings.catNamePlaceholder');
  setText('neighbor-label', t('settings.neighborLabel'));
  setText('neighbor-notice', t('neighbor.notice'));
  setText('websearch-label', t('websearch.label'));
  updateWebSearchUI();
  renderSkins();
  renderProfileSection();
  updateSummaries();
}

// 상단 요약 칩 갱신 (현재 AI / 고양이 이름 / 언어)
function updateSummaries() {
  const aiLabel = presetById[cur.presetId]
    ? friendlyLabel(cur.presetId, presetById[cur.presetId].label, t) : cur.presetId;
  setText('current-ai-chip', aiLabel || t('settings.navAiSub'));
  setText('current-cat-chip', cur.catName ? cur.catName : t('settings.catNamePlaceholder'));
  const langName = { ko: '한국어', en: 'English', ja: '日本語', zh: '简体中文' }[cur.resolvedLang] || '';
  setText('current-lang-chip', langName || t('settings.navGeneralSub'));
}

// --- depth 라우터 ------------------------------------------------------------
function showPage(id) {
  document.querySelectorAll('.page').forEach((p) => p.classList.toggle('active', p.id === id));
  window.scrollTo(0, 0);
  if (id !== 'page-home') { const c = $('connect'); if (c) { c.classList.remove('show'); c.innerHTML = ''; } }
  status('');
  fit();
}

function initNav() {
  document.querySelectorAll('[data-back]').forEach((b) => {
    b.addEventListener('click', () => showPage('page-home'));
  });
}

init();
