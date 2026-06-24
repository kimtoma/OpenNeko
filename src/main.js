const { app, BrowserWindow, ipcMain, screen, Menu, clipboard, Tray, nativeImage, shell, systemPreferences } = require('electron');
const path = require('path');
const http = require('http');
const os = require('os');
const { exec, execFile, execFileSync } = require('child_process');
const { parseBehind, isDirty, updateDecision } = require('./updater');
const { createProvider } = require('./llm');
const { safeStorage } = require('electron');
const { makeStore } = require('./settings');
const { presetConfig, PRESETS, DEFAULT_PRESET_ID, resolveApiKey } = require('./llm/presets');
const { detectProviders } = require('./llm/detect');
const { augmentPath, spawnEnv } = require('./llm/pathEnv');
const fs = require('node:fs');
const { createI18n, resolveLang, SUPPORTED } = require('./i18n');
const { persona } = require('./llm/persona');
const { BUNDLED_SKINS, mergeSkins, resolveSkin } = require('./renderer/skins');
const { discoverSkills, buildSkillSystem, enabledSkills } = require('./skills');
const { localizeSkill, localizeSkills } = require('./skills/i18n');
const { buildProfileContext } = require('./profile');
const { randomUUID } = require('node:crypto');
const { createNeighborNet, coarsePresence } = require('./lan');
const { ensurePeerId, displayName } = require('./lan/identity');
const { dockAwareWindowBounds, estimateBottomDockRect } = require('./renderer/dragGeometry');
const { detectAgentProcessCpu } = require('./agentProcs');
const { pickDailyBgm } = require('./bgm');

// 상주 데스크탑 펫: uncaught 예외가 나도 Electron 기본 동작(모달 에러창)으로
// 이벤트 루프를 멈추면 안 된다(모달이 뜨면 브리지·트레이까지 먹통 + 단일 인스턴스
// 락을 쥔 채 좀비가 돼 재시작도 막는다). 로그만 남기고 계속 산다.
process.on('uncaughtException', (e) => {
  console.error('[openneko] uncaughtException (무시하고 계속):', e && e.stack || e);
});
process.on('unhandledRejection', (e) => {
  console.error('[openneko] unhandledRejection (무시하고 계속):', e);
});

const CURSOR_POLL_MS = 50;

let win = null;
let tray = null;
let cursorTimer = null;
let screenMetricsTimer = null;
let i18n = createI18n('en'); // 앱 준비 후 refreshI18n()으로 덮어씀

function currentLang() { return resolveLang(store().load().lang, app.getLocale()); }
function refreshI18n() { i18n = createI18n(currentLang()); }

const gotSingleInstanceLock = app.requestSingleInstanceLock();

function sameRect(a, b) {
  return !!a && !!b
    && a.x === b.x
    && a.y === b.y
    && a.width === b.width
    && a.height === b.height;
}

function currentDisplay() {
  if (!win || win.isDestroyed()) return screen.getPrimaryDisplay();
  return screen.getDisplayMatching(win.getBounds());
}

let dockInfoCache = { at: 0, value: null };
function readDockDefaults() {
  if (process.platform !== 'darwin') return null;
  const now = Date.now();
  if (now - dockInfoCache.at < 5000) return dockInfoCache.value;

  const read = (key) => {
    try { return execFileSync('defaults', ['read', 'com.apple.dock', key], { timeout: 600 }).toString().trim(); }
    catch { return ''; }
  };
  const countTiles = (key) => {
    const s = read(key);
    return (s.match(/\btile-data\b/g) || []).length;
  };

  const tileSize = parseFloat(read('tilesize')) || 44;
  const orientation = read('orientation') || 'bottom';
  const apps = countTiles('persistent-apps');
  const others = countTiles('persistent-others');
  const showRecents = read('show-recents') !== '0';
  const recents = showRecents ? countTiles('recent-apps') : 0;
  dockInfoCache = {
    at: now,
    value: { tileSize, orientation, itemCount: apps + others + recents },
  };
  return dockInfoCache.value;
}

function screenMetricsPayload(display) {
  if (!win || win.isDestroyed()) return null;
  const windowBounds = win.getBounds();
  const dock = readDockDefaults();
  const dockRect = dock && dock.orientation === 'bottom'
    ? estimateBottomDockRect({
      displayBounds: display.bounds,
      workArea: display.workArea,
      tileSize: dock.tileSize,
      itemCount: dock.itemCount,
    }) : null;
  return {
    workArea: display.workArea,
    displayBounds: display.bounds,
    dockRect,
    winX: windowBounds.x,
    winY: windowBounds.y,
    windowBounds,
  };
}

let lastScreenMetricsKey = '';
function updateScreenMetrics({ force = false } = {}) {
  if (!win || win.isDestroyed()) return;
  const display = currentDisplay();
  const nextBounds = dockAwareWindowBounds(display);
  if (!sameRect(win.getBounds(), nextBounds)) {
    win.setBounds(nextBounds, false);
  }

  const payload = screenMetricsPayload(display);
  if (!payload) return;
  const key = JSON.stringify({
    workArea: payload.workArea,
    displayBounds: payload.displayBounds,
    dockRect: payload.dockRect,
    windowBounds: payload.windowBounds,
  });
  if (force || key !== lastScreenMetricsKey) {
    lastScreenMetricsKey = key;
    win.webContents.send('screen-metrics', payload);
  }
}

function createWindow() {
  const display = screen.getPrimaryDisplay();

  // Dock이 바닥에 있을 땐 투명 창은 화면 바닥까지 확장하고, 렌더러의 바닥 좌표만 Dock 위로 잡는다.
  const bounds = dockAwareWindowBounds(display);
  win = new BrowserWindow({
    width: bounds.width,
    height: bounds.height,
    x: bounds.x,
    y: bounds.y,
    transparent: true,
    frame: false,
    resizable: false,
    alwaysOnTop: true,
    skipTaskbar: true,
    hasShadow: false,
    fullscreenable: false,
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,
      nodeIntegration: false,
    },
  });

  win.setAlwaysOnTop(true, 'floating');
  win.setVisibleOnAllWorkspaces(true, { visibleOnFullScreen: true });
  win.loadFile(path.join(__dirname, 'renderer', 'index.html'));
  win.webContents.on('did-finish-load', () => {
    win.webContents.send('sound-config', store().load().sound);
    win.webContents.send('lang-config', currentLang());
    updateScreenMetrics({ force: true });
    pushSkinConfig();
    pushCatConfig();
  });

  // 렌더러는 창 밖 커서를 볼 수 없으므로 메인이 전역 좌표를 흘려보낸다.
  cursorTimer = setInterval(() => {
    if (!win || win.isDestroyed()) return;
    const cursor = screen.getCursorScreenPoint();
    const [wx, wy] = win.getPosition();
    win.webContents.send('cursor', { x: cursor.x, y: cursor.y, winX: wx, winY: wy });
  }, CURSOR_POLL_MS);

  screenMetricsTimer = setInterval(() => updateScreenMetrics(), 500);
  win.on('closed', () => {
    if (cursorTimer) { clearInterval(cursorTimer); cursorTimer = null; }
    if (screenMetricsTimer) { clearInterval(screenMetricsTimer); screenMetricsTimer = null; }
  });
}

// 전폭 창 전환 후 창은 항상 고정 — move-window는 no-op.
// 고양이 위치 이동은 렌더러 내부의 state.catX/state.catY가 담당한다.
// 기존 인터페이스를 그대로 남겨 렌더러 코드가 IPC를 보내도 안전하게 무시.
ipcMain.on('move-window', (_e, _payload) => {
  // 창은 전폭 전체 높이로 고정 — 이동하지 않음
});

ipcMain.handle('get-work-area', () => {
  if (!win || win.isDestroyed()) return null;
  return screenMetricsPayload(currentDisplay());
});

// 고양이 몸 위가 아닐 때는 클릭이 아래 앱으로 통과되어야 한다
ipcMain.on('set-ignore-mouse', (_e, ignore) => {
  if (!win || win.isDestroyed()) return;
  win.setIgnoreMouseEvents(ignore, { forward: true });
});

ipcMain.on('focus-window', () => {
  if (!win || win.isDestroyed()) return;
  win.setIgnoreMouseEvents(false);
  // dock을 숨긴 accessory 앱은 win.focus()만으로 key window가 되지 못해 키 입력을 못 받는다.
  // app.focus({steal:true})로 앱을 전면 활성화해야 입력창이 포커스를 잡는다(macOS).
  if (process.platform === 'darwin') app.focus({ steal: true });
  win.focus();
});

// === AgentStatusBridge ======================================================
// 외부 에이전트가 고양이 상태를 미는 단일 진입점.
// 1) HTTP: POST http://127.0.0.1:48800/state {"state","source","message?"}
// 2) 프로세스 폴링: 알려진 에이전트 앱은 CPU 사용률로 추정
// 3) 글로벌 키보드: 사용자가 타이핑하면 typing 모드 (키 내용은 읽지 않음)

const BRIDGE_PORT = parseInt(process.env.OPENNEKO_PORT || '48800', 10);
const VALID_STATES = ['idle', 'thinking', 'coding', 'typing', 'waiting',
  'success', 'error', 'lunch', 'yawn', 'nap', 'click', 'hover', 'walk', 'jump'];

let currentAnim = 'unknown';
let keydownCount = 0; // 키보드 훅 진단용
ipcMain.on('anim-report', (_e, anim) => { currentAnim = String(anim).slice(0, 20); });

function sendAgentEvent(payload) {
  if (win && !win.isDestroyed()) win.webContents.send('agent-event', payload);
  if (neighborNet && payload && payload.state) neighborNet.setPresence(coarsePresence(payload.state));
}

function sendAgentState(name) { // 데모 메뉴용
  sendAgentEvent({ state: name, source: 'demo' });
}

// === 이웃 고양이 LAN 네트워크 ===============================================
let neighborNet = null;
function resolvedCatName() {
  const cur = store().load();
  return displayName(cur.catName, i18n.t('app.name'));
}
function selfInfo() {
  return { name: resolvedCatName(), skin: currentSkin() };
}
function startNeighbor() {
  const cur = store().load();
  if (!cur.neighbor.enabled || neighborNet) return;
  const pid = ensurePeerId(cur.peerId, randomUUID);
  if (pid !== cur.peerId) store().save({ ...cur, peerId: pid });
  neighborNet = createNeighborNet({
    myId: pid,
    getSelf: selfInfo,
    onEvent: (ev) => { if (win && !win.isDestroyed()) win.webContents.send('peer-event', ev); },
  });
  neighborNet.start();
}
function stopNeighbor() { if (neighborNet) { neighborNet.stop(); neighborNet = null; } }

// === OTA: git 셀프 업데이트 ===============================================
// 배포가 git clone(install.sh/ps1)이라 origin 대비 뒤처짐을 감지 → 알림 → 선택 시 적용.
let updateState = { available: false, behind: 0, busy: false, branch: 'main', checking: false };

function appDir() { return app.getAppPath(); }
function isGitInstall() { try { return fs.existsSync(path.join(appDir(), '.git')); } catch { return false; } }

function gitp(args, timeout = 20000) {
  return new Promise((resolve, reject) => {
    execFile('git', args, { cwd: appDir(), env: spawnEnv(), timeout }, (err, out) => (err ? reject(err) : resolve(String(out))));
  });
}
function npmp(args, timeout = 300000) {
  const bin = process.platform === 'win32' ? 'npm.cmd' : 'npm';
  return new Promise((resolve, reject) => {
    execFile(bin, args, { cwd: appDir(), env: spawnEnv(), timeout, shell: process.platform === 'win32' }, (err, out) => (err ? reject(err) : resolve(String(out))));
  });
}
function refreshTrayMenu() { if (tray) tray.setContextMenu(Menu.buildFromTemplate(buildMenuTemplate())); }

// silent=true면 결과 말풍선 없이 조용히(자동 점검용). 수동 점검은 항상 결과 표시.
async function checkForUpdate({ silent = false } = {}) {
  if (updateState.busy || updateState.checking) return;
  if (!isGitInstall()) { if (!silent) sendAgentEvent({ state: 'hover', source: 'update', message: i18n.t('update.notGit') }); return; }
  updateState.checking = true;
  try {
    const branch = (await gitp(['rev-parse', '--abbrev-ref', 'HEAD'])).trim() || 'main';
    await gitp(['fetch', '--quiet', 'origin', branch]);
    const behind = parseBehind(await gitp(['rev-list', '--count', `HEAD..origin/${branch}`]));
    // untracked 파일은 더티로 치지 않음 — ff-pull은 untracked가 있어도 되므로, 추적 파일 수정만 막는다.
    // (예: 생성한 에셋·로컬 잡파일이 있어도 "업데이트 없음/최신"을 정상 표시)
    const dirty = isDirty(await gitp(['status', '--porcelain', '--untracked-files=no']));
    const d = updateDecision({ isGit: true, behind, dirty });
    updateState.available = d.available; updateState.behind = d.behind; updateState.branch = branch;
    refreshTrayMenu();
    if (d.available) sendAgentEvent({ state: 'hover', source: 'update', message: i18n.t('update.available', { n: d.behind }) });
    else if (!silent) sendAgentEvent({ state: 'hover', source: 'update', message: d.reason === 'dirty' ? i18n.t('update.dirty') : i18n.t('update.upToDate') });
  } catch (e) {
    // 확인 단계 실패(네트워크/fetch 등)는 "업데이트 실패"(적용 실패용)와 구분 — 업데이트가 없는 것과도 다름.
    if (!silent) sendAgentEvent({ state: 'hover', source: 'update', message: i18n.t('update.checkFailed') });
  } finally {
    updateState.checking = false;
  }
}

async function applyUpdate() {
  if (updateState.busy || !updateState.available) return;
  updateState.busy = true; refreshTrayMenu();
  sendAgentEvent({ state: 'coding', source: 'update', message: i18n.t('update.updating') });
  try {
    await gitp(['pull', '--ff-only', 'origin', updateState.branch]);
    await npmp(['install', '--no-audit', '--no-fund']);
    await npmp(['run', 'build']);
    sendAgentEvent({ state: 'success', source: 'update', message: i18n.t('update.restart') });
    setTimeout(() => { app.relaunch(); app.exit(0); }, 1600);
  } catch (e) {
    updateState.busy = false; updateState.available = true; refreshTrayMenu();
    sendAgentEvent({ state: 'error', source: 'update', message: i18n.t('update.failed') });
  }
}

// === 채팅 (P1) =============================================================
let llmProvider = null;
let chatHistory = [];        // [{role:'user'|'assistant', text}] — 메모리에만, 멀티턴용
const CHAT_HISTORY_MAX = 12; // 최근 N개 메시지만 보관(=6턴)
let chatAbort = null;
let activeSkill = null;      // prompt 모드 스킬 활성화 중 — chat-send에 system 주입

let settingsStore = null;
function store() {
  if (!settingsStore) settingsStore = makeStore({ dir: app.getPath('userData'), safeStorage });
  return settingsStore;
}

function loginItemOptions(openAtLogin) {
  return {
    openAtLogin: !!openAtLogin,
    openAsHidden: false,
    path: process.execPath,
    args: app.isPackaged ? [] : [app.getAppPath()],
  };
}

function systemLaunchAtLogin() {
  try {
    return app.getLoginItemSettings(loginItemOptions(false)).openAtLogin === true;
  } catch {
    return false;
  }
}

function setLaunchAtLogin(enabled) {
  const next = !!enabled;
  try {
    app.setLoginItemSettings(loginItemOptions(next));
  } catch (e) {
    console.error('[openneko] setLoginItemSettings failed:', e && e.message || e);
  }
  const cur = store().load();
  store().save({ ...cur, launchAtLogin: next });
  return { ok: true, enabled: next, systemEnabled: systemLaunchAtLogin() };
}

// 보강된 PATH에서 실행파일 존재 확인 (login 셸 spawn 없이 동기).
function whichBin(bin) {
  const isWin = process.platform === 'win32';
  const sep = isWin ? ';' : ':';
  // Windows는 확장자(.cmd/.exe/...)를 붙여 찾는다(PATHEXT). 그 외는 그대로 + 실행권한 확인.
  const exts = isWin ? (process.env.PATHEXT || '.COM;.EXE;.BAT;.CMD').split(';') : [''];
  const mode = isWin ? fs.constants.F_OK : fs.constants.X_OK;
  const dirs = augmentPath(process.env.PATH).split(sep).filter(Boolean);
  return dirs.some((d) => exts.some((ext) => {
    try { fs.accessSync(path.join(d, bin + ext), mode); return true; } catch { return false; }
  }));
}

function execFileCapture(file, args, opts = {}) {
  return new Promise((resolve, reject) => {
    execFile(file, args, { ...opts, env: spawnEnv(process.env) }, (error, stdout, stderr) => {
      if (error) {
        error.stdout = stdout;
        error.stderr = stderr;
        reject(error);
        return;
      }
      resolve({ stdout, stderr });
    });
  });
}

function currentProviderConfig() {
  const s = store().load();
  const { provider, apiKey } = s;
  const lang = currentLang();
  const savedProvider = validProvider(provider) ? provider : null;
  if (!savedProvider) return { ...presetConfig(DEFAULT_PRESET_ID), apiKey: resolveApiKey(DEFAULT_PRESET_ID, apiKey), lang };
  return { ...savedProvider, apiKey: resolveApiKey(savedProvider.preset, apiKey), lang };
}
function ensureProvider() {
  if (!llmProvider) llmProvider = createProvider(currentProviderConfig());
  return llmProvider;
}

function validProvider(provider) {
  return !!(provider && PRESETS.some((p) => p.id === provider.preset));
}

// === 스킬 발견 =============================================================
function allSkillDefs() {
  const dirs = [
    path.join(__dirname, 'skills', 'builtin'),
    path.join(os.homedir(), '.openneko', 'skills'),
  ];
  return discoverSkills({
    dirs,
    readdir: (d) => fs.readdirSync(d),
    readFile: (f) => fs.readFileSync(f, 'utf8'),
    exists: (p) => fs.existsSync(p),
  });
}

function enabledSkillDefs(lang = currentLang()) {
  return localizeSkills(enabledSkills(allSkillDefs(), store().load().disabledSkills), lang);
}

function findSkill(id, lang = currentLang()) {
  const skill = allSkillDefs().find((s) => s.id === id);
  return skill ? localizeSkill(skill, lang) : skill;
}

function classifyChatError(e) {
  if (e && e.code === 'ENOENT') return i18n.t('chat.errNotReady');
  if (e && e.code === 'ETIMEDOUT') return i18n.t('chat.errTimeout');
  if (e && e.code === 'AUTH') return i18n.t('chat.errAuth');
  if (e && e.code === 'NOTFOUND') return i18n.t('chat.errNotFound');
  if (e && /ECONNREFUSED|fetch failed|ENOTFOUND/.test(e.message || '')) return i18n.t('chat.errConn');
  return i18n.t('chat.errGeneric');
}

// 시스템 프롬프트 합성: 스킬 본문(있으면) + 페르소나 + 프로필/오늘날짜 컨텍스트
function composeSystem({ skill, lang }) {
  const localizedSkill = skill ? localizeSkill(skill, lang) : null;
  const base = localizedSkill ? buildSkillSystem(localizedSkill, persona(lang)) : persona(lang);
  return base + '\n\n' + buildProfileContext(store().load().profile, new Date());
}

// seq: 렌더러가 보낸 턴 식별자. 응답에 그대로 실어 보내, 닫혔거나 새 질문으로 바뀐 뒤
// 늦게 도착한 응답을 렌더러가 버릴 수 있게 한다(stale reply 방지).
ipcMain.on('chat-send', async (_e, payload) => {
  const { text, seq } = payload || {};
  const msg = String(text || '').slice(0, 2000).trim();
  if (!msg || !win || win.isDestroyed()) return;
  if (chatAbort) chatAbort.abort();
  chatAbort = new AbortController();
  chatHistory.push({ role: 'user', text: msg });
  if (chatHistory.length > CHAT_HISTORY_MAX) chatHistory = chatHistory.slice(-CHAT_HISTORY_MAX);
  win.webContents.send('chat-thinking');
  try {
    // 활성 스킬이 그새 비활성/삭제됐으면 해제(꺼진 스킬 지침이 계속 주입되는 것 방지)
    if (activeSkill && !enabledSkillDefs().some((s) => s.id === activeSkill.id)) activeSkill = null;
    const skillSystem = composeSystem({ skill: activeSkill, lang: currentLang() });
    const res = await ensureProvider().chat({
      history: chatHistory,
      signal: chatAbort.signal,
      system: skillSystem,
      onDelta: (chunk) => { if (win && !win.isDestroyed()) win.webContents.send('chat-delta', { text: chunk, seq }); },
    });
    chatHistory.push({ role: 'assistant', text: res.text });
    if (win && !win.isDestroyed()) win.webContents.send('chat-reply', { text: res.text, seq });
  } catch (e) {
    if (e && e.name === 'AbortError') return; // 새 메시지로 취소된 것
    chatHistory.pop(); // 실패한 user 턴은 이력에서 제거
    if (win && !win.isDestroyed()) win.webContents.send('chat-error', { msg: classifyChatError(e), seq });
  }
});

ipcMain.on('chat-reset', () => {
  if (chatAbort) chatAbort.abort();
  chatHistory = [];
  activeSkill = null;
});

function stripKey(f) { const { apiKey, ...rest } = f || {}; return rest; }
function providerNeedsKey(presetId) {
  const p = PRESETS.find((x) => x.id === presetId);
  return !!(p && (p.fields || []).includes('apiKey'));
}
function providerRequiresKey(presetId) {
  const p = PRESETS.find((x) => x.id === presetId);
  return !!(p && p.requiresApiKey === true);
}
function resolveKey(fields) { return (fields && 'apiKey' in fields) ? fields.apiKey : store().load().apiKey; }
function keyForSave(presetId, fields, cur) {
  if (!providerNeedsKey(presetId)) return '';
  if (fields && 'apiKey' in fields) return fields.apiKey;
  return cur.provider && cur.provider.preset === presetId ? cur.apiKey : '';
}
function keyForTest(presetId, fields) {
  if (fields && 'apiKey' in fields) return fields.apiKey;
  const cur = store().load();
  return cur.provider && cur.provider.preset === presetId ? cur.apiKey : '';
}

ipcMain.handle('settings-get', () => {
  const { provider, apiKey, sound, lang, onboarded, webSearch, profile, neighbor, catName, launchAtLogin } = store().load();
  const savedProvider = validProvider(provider) ? provider : null;
  return {
    provider: savedProvider, hasKey: !!(savedProvider && providerNeedsKey(savedProvider.preset) && apiKey),
    presetId: savedProvider ? savedProvider.preset : DEFAULT_PRESET_ID,
    sound, lang, resolvedLang: currentLang(), skin: currentSkin(),
    onboarding: !onboarded,
    webSearch: webSearch !== false,
    profile: profile || {},
    neighbor,
    catName,
    launchAtLogin: !!launchAtLogin || systemLaunchAtLogin(),
  };
});

ipcMain.handle('cat-name-set', (_e, { name }) => {
  const cur = store().load();
  store().save({ ...cur, catName: name != null ? String(name).slice(0, 64) : cur.catName });
  pushCatConfig();
  if (neighborNet) { stopNeighbor(); startNeighbor(); }
  return { ok: true };
});

ipcMain.handle('profile-set', (_e, { profile }) => {
  const cur = store().load();
  store().save({ ...cur, profile: profile || {} });
  return { ok: true };
});

ipcMain.on('neighbor-wave', (_e, id) => {
  if (!neighborNet || typeof id !== 'string') return;
  neighborNet.sendWave(id);
  neighborNet.sendGreeting(id, Math.floor(Math.random() * 4));
});
ipcMain.handle('neighbor-set', (_e, { enabled, displayName: dn }) => {
  const cur = store().load();
  const neighbor = { enabled: enabled != null ? !!enabled : cur.neighbor.enabled,
    displayName: dn != null ? String(dn).slice(0, 64) : cur.neighbor.displayName };
  store().save({ ...cur, neighbor });
  if (neighbor.enabled) startNeighbor(); else stopNeighbor();
  return { ok: true };
});

ipcMain.handle('websearch-set', (_e, { enabled }) => {
  const cur = store().load();
  store().save({ ...cur, webSearch: !!enabled });
  llmProvider = null;
  return { ok: true };
});

ipcMain.handle('launch-at-login-set', (_e, { enabled }) => setLaunchAtLogin(enabled));

ipcMain.handle('settings-save', (_e, { presetId, fields }) => {
  const provider = presetConfig(presetId, stripKey(fields));
  try {
    const cur = store().load();
    // sound·lang·skin·온보딩 필드는 provider와 독립 — 저장 시 보존
    store().save({ ...cur, provider, apiKey: keyForSave(provider.preset, fields, cur) });
    llmProvider = null; return { ok: true };
  }
  catch (e) { return { ok: false, error: e.message }; }
});

function pushSoundConfig() {
  if (win && !win.isDestroyed()) win.webContents.send('sound-config', store().load().sound);
}
// 사운드 on/off를 저장하고 렌더러에 반영. 설정창·메뉴바·IPC가 공유.
function setSoundEnabled(enabled) {
  const cur = store().load();
  store().save({ ...cur, sound: { enabled: !!enabled } });
  pushSoundConfig();
}
function soundEnabled() { return store().load().sound.enabled !== false; }
ipcMain.handle('sound-set', (_e, { enabled }) => {
  setSoundEnabled(enabled);
  return { ok: true };
});
function pushLangConfig() {
  if (win && !win.isDestroyed()) win.webContents.send('lang-config', currentLang());
}

// 언어 변경 헬퍼 — lang-set IPC와 chat-slash 라우터가 공유
function applyLang(code) {
  if (!SUPPORTED.includes(code)) return { ok: false };
  const cur = store().load();
  store().save({ ...cur, lang: code });
  refreshI18n();
  llmProvider = null;
  pushLangConfig();
  if (tray) tray.setContextMenu(Menu.buildFromTemplate(buildMenuTemplate()));
  return { ok: true };
}

ipcMain.handle('lang-set', (_e, { lang }) => {
  // 기존 동작 유지: 미지원 코드면 null(OS 기본)로 저장
  const code = SUPPORTED.includes(lang) ? lang : null;
  if (code) {
    applyLang(code);
  } else {
    const cur = store().load();
    store().save({ ...cur, lang: null });
    refreshI18n();
    llmProvider = null;
    pushLangConfig();
    if (tray) tray.setContextMenu(Menu.buildFromTemplate(buildMenuTemplate()));
  }
  return { ok: true, lang: currentLang() };
});

function externalSkins() {
  try {
    const skinsDir = path.join(app.getPath('userData'), 'skins');
    if (!fs.existsSync(skinsDir)) return [];
    return fs.readdirSync(skinsDir, { withFileTypes: true })
      .filter((d) => d.isDirectory())
      .map((d) => {
        const id = d.name;
        let label = id;
        try {
          const meta = JSON.parse(fs.readFileSync(path.join(skinsDir, id, 'skin.json'), 'utf8'));
          if (meta && meta.label) label = meta.label;
        } catch { /* no skin.json or parse error — use id as label */ }
        // pathToFileURL로 인코딩 — 기본 경로 "Application Support"의 공백/유니코드 깨짐 방지
        const base = require('node:url').pathToFileURL(path.join(skinsDir, id) + path.sep).href;
        return { id, label, base };
      });
  } catch { return []; }
}
function allSkins() { return mergeSkins(BUNDLED_SKINS, externalSkins()); }
function currentSkin() { return resolveSkin(store().load().skin, allSkins()); }
function skinBase(id) { const s = allSkins().find((x) => x.id === id); return s ? s.base : 'sprites/'; }
function pushSkinConfig() {
  if (win && !win.isDestroyed()) win.webContents.send('skin-config', skinBase(currentSkin()));
}

// 설정창은 src/settings/에서 로드되므로 렌더러 상대경로(`sprites/...`)를 못 쓴다.
// idle_0 미리보기를 절대 file:// URL로 만들어 같이 내려준다.
function skinPreview(base) {
  if (base && base.startsWith('sprites/')) {
    return require('node:url').pathToFileURL(path.join(__dirname, 'renderer', base, 'idle_0.png')).href;
  }
  return base ? base + 'idle_0.png' : ''; // 외부 팩 base는 이미 file:// URL
}
ipcMain.handle('skins-list', () => {
  return allSkins().map(({ id, labelKey, label, swatch, base }) => ({ id, labelKey, label, swatch, base, preview: skinPreview(base) }));
});

function pushCatConfig() {
  if (win && !win.isDestroyed()) win.webContents.send('cat-config', { name: resolvedCatName() });
}

// 스킨 변경 헬퍼 — skin-set IPC와 chat-slash 라우터가 공유. 모든 스킨 무료(잠금 없음).
function applySkin(id) {
  const skinIds = allSkins().map((s) => s.id);
  const cur = store().load();
  const sk = skinIds.includes(id) ? id : 'white';
  store().save({ ...cur, skin: sk });
  pushSkinConfig();
  return { ok: true };
}

ipcMain.handle('skin-set', (_e, { id }) => {
  return applySkin(id);
});

// 첫 실행 환영 화면에서 스킨 선택 → 스킨 설정 + 온보딩 완료 표시(1회성 배너 숨김용)
ipcMain.handle('onboard-pick', (_e, { id }) => {
  const cur = store().load();
  if (cur.onboarded) return { ok: false };
  if (!allSkins().some((s) => s.id === id)) return { ok: false };
  store().save({ ...cur, skin: id, onboarded: true });
  pushSkinConfig();
  return { ok: true };
});

// 온보딩 위저드 완료 — 마지막 스텝에서 호출. 고양이가 축하 인사.
ipcMain.handle('onboard-complete', () => {
  const cur = store().load();
  store().save({ ...cur, onboarded: true });
  sendAgentEvent({ state: 'success', source: 'onboard', message: i18n.t('onboard.done') });
  return { ok: true };
});

// 온보딩 권한 스텝: macOS 손쉬운 사용 신뢰 여부 + 키 입력 감지 여부(입력 모니터링 프록시).
ipcMain.handle('onboard-perm-status', () => {
  const platform = process.platform;
  let accessibility = true;
  if (platform === 'darwin') {
    try { accessibility = systemPreferences.isTrustedAccessibilityClient(false); } catch { accessibility = false; }
  }
  return { platform, accessibility, inputSeen: keydownCount > 0 };
});

// 온보딩 권한 스텝: macOS 개인정보 보호 설정 해당 창으로 딥링크.
ipcMain.handle('onboard-open-perms', (_e, { which }) => {
  if (process.platform !== 'darwin') return { ok: false };
  const url = which === 'input'
    ? 'x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent'
    : 'x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility';
  shell.openExternal(url);
  return { ok: true };
});
ipcMain.handle('settings-test', async (_e, { presetId, fields }) => {
  try {
    const p = createProvider({ ...presetConfig(presetId, stripKey(fields)), apiKey: resolveApiKey(presetId, keyForTest(presetId, fields)) });
    const r = await p.chat({ history: [{ role: 'user', text: '안녕? 한 단어로 인사해' }] });
    return { ok: true, text: r.text };
  } catch (e) { return { ok: false, error: classifyChatError(e) + ' (' + (e.message || '') + ')' }; }
});
ipcMain.handle('settings-presets', () => PRESETS.map(({
  id, label, fields, defaults, note, cliBin, local, recommended, requiresApiKey,
}) => ({ id, label, fields, defaults, note, cliBin, local, recommended, requiresApiKey })));
ipcMain.handle('settings-detect', async () => {
  try {
    const f = typeof fetch !== 'undefined' ? (...a) => fetch(...a) : undefined;
    return await detectProviders({ env: process.env, which: whichBin, execFile: execFileCapture, fetch: f });
  } catch { return []; }
});

// 스킬 원샷 실행: clipboard/none 입력 모드. 대화 이력과 별개의 단발 호출.
// inputOverride가 있으면 그 텍스트를 input으로 사용(클립보드/none 로직 건너뜀).
async function runSkill(skill, inputOverride) {
  if (!win || win.isDestroyed()) return;
  if (skill.id === 'daily-bgm') {
    await runBgmSkill(inputOverride);
    return;
  }
  let input;
  if (inputOverride !== undefined) {
    input = String(inputOverride).slice(0, 6000);
  } else if (skill.input === 'clipboard') {
    const clip = clipboard.readText().trim();
    if (!clip) {
      win.webContents.send('skill-error', i18n.t('skill.noClipboard'));
      return;
    }
    input = clip.slice(0, 6000);
  } else {
    // input === 'none'
    input = '(시작)';
  }
  if (chatAbort) chatAbort.abort();
  chatAbort = new AbortController();
  win.webContents.send('skill-thinking');
  try {
    const res = await ensureProvider().chat({
      history: [{ role: 'user', text: input }],
      signal: chatAbort.signal,
      system: composeSystem({ skill, lang: currentLang() }),
    });
    if (win && !win.isDestroyed()) win.webContents.send('skill-reply', res.text);
  } catch (e) {
    if (e && e.name === 'AbortError') return;
    if (win && !win.isDestroyed()) win.webContents.send('skill-error', classifyChatError(e));
  }
}

async function runBgmSkill(inputOverride) {
  if (!win || win.isDestroyed()) return;
  const arg = String(inputOverride || '').trim().toLowerCase();
  win.webContents.send('skill-thinking');
  if (/^(stop|off|pause|정지|중지|끄기)$/.test(arg)) {
    win.webContents.send('bgm-stop');
    win.webContents.send('skill-reply', i18n.t('skill.bgmStopped'));
    return;
  }
  const cur = store().load();
  const bgm = pickDailyBgm(new Date(), {
    preference: inputOverride,
    profile: cur.profile || {},
    lang: currentLang(),
  });
  win.webContents.send('bgm-stop');
  try {
    await shell.openExternal(bgm.url);
    win.webContents.send('skill-reply', i18n.t('skill.bgmPlaying', {
      title: bgm.title,
      query: bgm.query,
      service: bgm.service,
      personalized: bgm.personalized ? i18n.t('skill.bgmPersonalized') : '',
    }));
  } catch (e) {
    win.webContents.send('skill-error', (e && e.message) || i18n.t('chat.errGeneric'));
  }
}

function startBridge() {
  const server = http.createServer((req, res) => {
    if (req.method === 'POST' && req.url === '/state') {
      let body = '';
      req.on('data', (c) => { body += c; if (body.length > 4096) req.destroy(); });
      req.on('end', () => {
        try {
          const { state, source, message } = JSON.parse(body || '{}');
          if (!VALID_STATES.includes(state)) throw new Error('bad state');
          sendAgentEvent({
            state,
            source: String(source || 'agent').slice(0, 40),
            message: message ? String(message).slice(0, 120) : undefined,
          });
          res.writeHead(200); res.end('ok');
        } catch {
          res.writeHead(400); res.end('bad request');
        }
      });
    } else if (req.url === '/health') {
      res.writeHead(200); res.end('openneko');
    } else if (req.url === '/anim') {
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ anim: currentAnim, keydownCount }));
    } else if (req.url === '/pos') {
      // 드래그/위치 디버그: 창 위치 + 작업영역
      res.writeHead(200, { 'Content-Type': 'application/json' });
      if (!win || win.isDestroyed()) { res.end('{}'); return; }
      res.end(JSON.stringify(screenMetricsPayload(currentDisplay())));
    } else if (req.url === '/capture') {
      // 시각 검증용: 현재 창(고양이) 렌더 결과를 투명 PNG로 반환. 화면 좌표 몰라도 캡처 가능.
      if (!win || win.isDestroyed()) { res.writeHead(503); res.end(); return; }
      win.webContents.capturePage().then((img) => {
        res.writeHead(200, { 'Content-Type': 'image/png' });
        res.end(img.toPNG());
      }).catch(() => { res.writeHead(500); res.end(); });
    } else {
      res.writeHead(404); res.end();
    }
  });
  server.on('error', (e) => console.log('bridge disabled:', e.message)); // 포트 점유 등
  server.listen(BRIDGE_PORT, '127.0.0.1');
}

function startProcPoller() {
  // Windows에선 CLI가 node.exe로 감싸 실행돼 프로세스명/CPU 매칭이 불안정 → CPU 폴러 비활성.
  // 대신 OS 무관한 HTTP 브리지(:48800/state)로 상태를 받는다(README/연동 참고).
  if (process.platform === 'win32') return;
  setInterval(() => {
    exec('ps -axo pcpu=,args=', { maxBuffer: 4 * 1024 * 1024 }, (err, out) => {
      if (err || !win || win.isDestroyed()) return;
      win.webContents.send('agent-procs', detectAgentProcessCpu(out));
    });
  }, 3000);
}

// 글로벌 키보드: keydown 발생 사실만 전달 (키 코드/내용은 사용하지 않음)
function startKeyboardWatch() {
  try {
    const { uIOhook } = require('uiohook-napi');
    let last = 0;
    const TYPING_IPC_MS = 50; // 키 입력 → typing 프레임 전진 주기 (낮을수록 손이 타이핑 속도를 촘촘히 따라감)
    uIOhook.on('keydown', () => {
      keydownCount++;
      const now = Date.now();
      if (now - last > TYPING_IPC_MS) {
        last = now;
        if (win && !win.isDestroyed()) win.webContents.send('user-typing', now);
      }
    });
    uIOhook.start();
  } catch (e) {
    console.log('keyboard hook unavailable:', e.message); // 권한 없음 등 — 기능만 비활성
  }
}

let settingsWin = null;
function openSettingsWindow() {
  if (settingsWin && !settingsWin.isDestroyed()) { settingsWin.show(); settingsWin.focus(); return; }
  settingsWin = new BrowserWindow({
    width: 560, height: 680, minWidth: 520, minHeight: 420, resizable: true, title: i18n.t('app.name') + ' ' + i18n.t('menu.settings'), // 로드 후 콘텐츠 높이로 자동 맞춤(settings-resize)
    webPreferences: { preload: path.join(__dirname, 'preloadSettings.js'), contextIsolation: true, nodeIntegration: false },
  });
  settingsWin.loadFile(path.join(__dirname, 'settings', 'settings.html'));
  if (process.platform === 'darwin') app.focus({ steal: true });
}

// 설정창이 콘텐츠 높이에 맞춰 세로 스크롤이 안 생기게 — 렌더러가 본문 높이를 보내면 창을 맞춘다.
ipcMain.on('settings-resize', (_e, height) => {
  if (!settingsWin || settingsWin.isDestroyed()) return;
  const wa = screen.getDisplayMatching(settingsWin.getBounds()).workArea;
  const [w] = settingsWin.getContentSize();
  const h = Math.max(220, Math.min(Math.round(height), wa.height - 60));
  settingsWin.setContentSize(w, h);
});

// 외부 링크(크레딧의 홈페이지)는 기본 브라우저로 — https만 허용.
ipcMain.handle('open-external', (_e, url) => {
  if (typeof url === 'string' && /^https:\/\//.test(url)) shell.openExternal(url);
});

// === 스킬 IPC =============================================================
ipcMain.handle('skills-list', () => {
  const disabled = new Set(store().load().disabledSkills);
  return localizeSkills(allSkillDefs(), currentLang()).map((s) => ({
    id: s.id, name: s.name, description: s.description,
    input: s.input, source: s.source, enabled: !disabled.has(s.id),
  }));
});

ipcMain.handle('run-skill', (_e, { id }) => {
  const s = findSkill(id);
  if (!s) return;
  if (s.input !== 'prompt') runSkill(s);
});

// prompt 스킬 활성화 공통. 다른 스킬로 바뀌면 이전 대화는 새 스킬 지침에 섞이지 않게 리셋.
function setActiveSkill(s) {
  if (activeSkill && activeSkill.id !== s.id) chatHistory = [];
  activeSkill = s;
  if (win && !win.isDestroyed()) win.webContents.send('skill-active', { name: s.name });
}

ipcMain.handle('skill-activate', (_e, { id }) => {
  const s = findSkill(id);
  if (!s || s.input !== 'prompt') return;
  setActiveSkill(s);
});

ipcMain.handle('skill-enabled', (_e, { id, enabled }) => {
  const cur = store().load();
  const dis = new Set(cur.disabledSkills);
  if (enabled) dis.delete(id); else dis.add(id);
  store().save({ ...cur, disabledSkills: [...dis] });
  if (!enabled && activeSkill && activeSkill.id === id) activeSkill = null; // 끈 스킬이 활성 중이면 해제
  // 메뉴 재생성
  if (tray) tray.setContextMenu(Menu.buildFromTemplate(buildMenuTemplate()));
  return { ok: true };
});

ipcMain.handle('open-skills-folder', () => {
  const dir = path.join(os.homedir(), '.openneko', 'skills');
  fs.mkdirSync(dir, { recursive: true });
  shell.openPath(dir);
});

// === 슬래시 명령 카탈로그 + 라우터 ==========================================

// 슬래시 명령 카탈로그 반환: 켜진 스킬 + 기본/앱 명령, i18n 설명
ipcMain.handle('slash-commands', () => {
  const builtins = [
    { name: 'help', kind: 'builtin', desc: i18n.t('cmd.help') },
    { name: 'reset', kind: 'builtin', desc: i18n.t('cmd.reset') },
  ];
  const appCmds = [
    { name: 'skin', kind: 'app', desc: i18n.t('cmd.skin') },
    { name: 'lang', kind: 'app', desc: i18n.t('cmd.lang') },
    { name: 'sound', kind: 'app', desc: i18n.t('cmd.sound') },
  ];
  const skills = enabledSkillDefs().map((s) => ({
    name: s.id,
    kind: 'skill',
    desc: s.description || s.name,
  }));
  return [...builtins, ...appCmds, ...skills];
});

// 슬래시 명령 라우터: 렌더러가 /help·/reset 외의 명령을 여기로 보냄
ipcMain.handle('chat-slash', (_e, { cmd, args }) => {
  const c = String(cmd || '').toLowerCase();
  const a = String(args || '').trim();

  // 스킬 명령: 켜진 스킬 id와 일치할 때
  const skill = findSkill(c);
  if (skill && enabledSkillDefs().some((s) => s.id === c)) {
    if (a) {
      // args 있으면 그 텍스트로 원샷 실행
      runSkill(skill, a);
    } else {
      // args 없으면 input 모델대로
      if (skill.input === 'prompt') {
        setActiveSkill(skill);
      } else {
        runSkill(skill);
      }
    }
    return { ok: true };
  }

  // 스킨 변경 (모든 스킨 무료)
  if (c === 'skin') {
    const r = applySkin(a);
    if (r.ok) {
      if (win && !win.isDestroyed()) win.webContents.send('skill-reply', i18n.t('slash.changed'));
    } else {
      if (win && !win.isDestroyed()) win.webContents.send('skill-error', i18n.t('slash.unknown'));
    }
    return { ok: r.ok };
  }

  // 언어 변경
  if (c === 'lang') {
    const r = applyLang(a);
    if (r.ok) {
      if (win && !win.isDestroyed()) win.webContents.send('skill-reply', i18n.t('slash.changed'));
    } else {
      if (win && !win.isDestroyed()) win.webContents.send('skill-error', i18n.t('slash.unknown'));
    }
    return { ok: r.ok };
  }

  // 사운드 on/off
  if (c === 'sound') {
    const on = /^on$/i.test(a);
    const off = /^off$/i.test(a);
    if (on || off) {
      setSoundEnabled(on);
      if (win && !win.isDestroyed()) win.webContents.send('skill-reply', i18n.t('slash.changed'));
      return { ok: true };
    }
    if (win && !win.isDestroyed()) win.webContents.send('skill-error', i18n.t('slash.unknown'));
    return { ok: false };
  }

  // 미지원 명령
  if (win && !win.isDestroyed()) win.webContents.send('skill-error', i18n.t('slash.unknown'));
  return { ok: false };
});

// prompt 스킬을 메뉴에서 발동
function activateSkillFromMenu(skill) {
  setActiveSkill(skill);
}

// 고양이 우클릭 메뉴 / 메뉴바(Tray) 메뉴 공통 템플릿. 매번 새로 만들어 현재 상태 반영.
function buildMenuTemplate() {
  const alive = win && !win.isDestroyed();
  const visible = alive && win.isVisible();
  // 매번 새로 만들므로 checkbox의 checked가 현재 상태를 반영.
  return [
    { label: i18n.t('app.name'), enabled: false },
    { type: 'separator' },
    { label: visible ? i18n.t('menu.hide', { name: i18n.t('app.name') }) : i18n.t('menu.show', { name: i18n.t('app.name') }),
      click: () => { if (!alive) return; if (win.isVisible()) win.hide(); else { win.showInactive(); win.moveTop(); } } },
    { label: i18n.t('menu.alwaysOnTop'), type: 'checkbox', checked: !!(alive && win.isAlwaysOnTop()),
      click: (item) => alive && win.setAlwaysOnTop(item.checked, 'floating') },
    { label: i18n.t('menu.sound'), type: 'checkbox', checked: soundEnabled(),
      click: (item) => setSoundEnabled(item.checked) },
    { type: 'separator' },
    {
      label: i18n.t('menu.skills'),
      submenu: (() => {
        const skills = enabledSkillDefs();
        if (skills.length === 0) {
          return [{ label: i18n.t('skills.empty'), enabled: false }];
        }
        return skills.map((s) => ({
          label: s.name,
          click: () => {
            if (s.input === 'prompt') activateSkillFromMenu(s);
            else runSkill(s);
          },
        }));
      })(),
    },
    {
      label: i18n.t('menu.preview'),
      submenu: [
        { label: '🤔 ' + i18n.t('state.thinking'), click: () => sendAgentState('thinking') },
        { label: '💻 ' + i18n.t('state.coding'), click: () => sendAgentState('coding') },
        { label: '⌨️ ' + i18n.t('state.typing'), click: () => sendAgentState('typing') },
        { label: '✨ ' + i18n.t('state.success'), click: () => sendAgentState('success') },
        { label: '⚡ ' + i18n.t('state.error'), click: () => sendAgentState('error') },
        { label: '🚶 ' + i18n.t('state.walk'), click: () => sendAgentState('walk') },
        { label: '🦘 ' + i18n.t('state.jump'), click: () => sendAgentState('jump') },
        { label: '🥱 ' + i18n.t('state.yawn'), click: () => sendAgentState('yawn') },
        { label: '🍜 ' + i18n.t('state.lunch'), click: () => sendAgentState('lunch') },
        { label: '💤 ' + i18n.t('state.nap'), click: () => sendAgentState('nap') },
        { type: 'separator' },
        { label: i18n.t('menu.previewIdle'), click: () => sendAgentState('idle') },
      ],
    },
    { label: i18n.t('menu.settings'), click: () => openSettingsWindow() },
    { type: 'separator' },
    // OTA: 업데이트가 있으면 적용 항목, 없으면 수동 점검 항목
    updateState.busy
      ? { label: i18n.t('update.updating'), enabled: false }
      : updateState.available
        ? { label: i18n.t('update.menuApply', { n: updateState.behind }), click: () => applyUpdate() }
        : { label: i18n.t('update.menuCheck'), enabled: !updateState.checking, click: () => checkForUpdate({ silent: false }) },
    { type: 'separator' },
    { label: i18n.t('menu.quit'), click: () => app.quit() },
  ];
}

ipcMain.on('show-context-menu', () => {
  if (win && !win.isDestroyed()) Menu.buildFromTemplate(buildMenuTemplate()).popup({ window: win });
});

// 메뉴바(상태바) 아이콘
function createTray() {
  try {
    const img = nativeImage.createFromPath(path.join(__dirname, 'icons', 'trayTemplate.png'));
    img.setTemplateImage(true); // macOS 다크/라이트 메뉴바에 맞춰 자동 반전
    tray = new Tray(img);
    tray.setToolTip(i18n.t('app.name'));
    const open = () => tray.popUpContextMenu(Menu.buildFromTemplate(buildMenuTemplate()));
    tray.on('click', open);
    tray.on('right-click', open);
  } catch (e) {
    console.log('tray unavailable:', e.message);
  }
}

if (!gotSingleInstanceLock) {
  app.quit();
} else {
  app.on('second-instance', () => {
    if (!win || win.isDestroyed()) return;
    win.show();
    win.moveTop();
  });

  // Dock 아이콘 클릭 → 고양이 보이기 (닫혔으면 다시 생성)
  app.on('activate', () => {
    if (!win || win.isDestroyed()) createWindow();
    else { win.show(); win.moveTop(); }
  });

  app.whenReady().then(() => {
    // Dock 아이콘 없이 메뉴바(Tray)에서만 — accessory 앱. (키 입력 포커스는 focus-window의 app.focus steal로 처리)
    if (process.platform === 'darwin') app.dock?.hide();
    refreshI18n(); // OS 로케일 및 저장 lang으로 i18n 초기화
    createWindow();
    createTray();
    startBridge();
    startProcPoller();
    startKeyboardWatch();
    startNeighbor();
    if (store().load().launchAtLogin) setLaunchAtLogin(true);

    // 첫 실행 환영: onboarded가 아직 아니면 설정창(온보딩 위저드) 자동 열기 + 고양이 인사 말풍선
    if (!store().load().onboarded) {
      openSettingsWindow();
      setTimeout(() => sendAgentEvent({ state: 'success', source: 'onboard', message: i18n.t('onboard.greet') }), 1200);
    } else {
      // OTA: 첫 실행이 아니면 잠시 후 조용히 업데이트 점검 (있으면 말풍선 + 트레이로 안내)
      setTimeout(() => checkForUpdate({ silent: true }), 8000);
    }
  });
}

// 창을 숨겨도(Tray/Dock 상주) 앱은 살아있게 — 모든 창이 닫혀도 종료하지 않음
app.on('window-all-closed', () => {
  // 트레이/독으로 계속 상주. (실제 종료는 메뉴의 '잘 가, 냥')
});

app.on('before-quit', () => stopNeighbor());
