// openNeko 2D pixel sprite renderer.
// 인터랙션/리추얼/AgentStatusBridge 로직은 3D 버전 그대로, 렌더링만 스프라이트 애니메이션
import manifest from './sprites/manifest.json';
const { createSounds } = require('./sound');
const { DEFAULT_PIN_OFFSET_Y, clampDraggedCat, dockAwareFloorY, fallY } = require('./dragGeometry');
const { createI18n } = require('../i18n');
const { parseSlash, matchCommands } = require('../slash');
const { skinSpriteBase } = require('./skins');

let i18n = createI18n('en'); // lang-config IPC로 갱신

// --- 손님 고양이 (이웃 LAN 피어) -------------------------------------------------------

const GUEST_PRESENCE_ANIM = { idle: 'idle', coding: 'coding', typing: 'typing', away: 'nap' };
const GUEST_VISIT_MS = 25000; // 인사 없이 머무는 기본 체류 시간
const guests = new Map(); // id -> {name, base, x, dir, mode, anim, animStart, targetX, bubbleText, bubbleUntil, leaveAt}

let myCatName = '';
window.kat.onCatConfig((cfg) => { myCatName = (cfg && cfg.name) || ''; });

function spawnGuest(id, name, skin) {
  const fromLeft = Math.random() < 0.5;
  const x = fromLeft ? -SIZE : window.innerWidth;
  const targetX = Math.max(SIZE, Math.min(window.innerWidth - SIZE * 2,
    state.catX + (fromLeft ? -SIZE * 1.1 : SIZE * 1.1)));
  guests.set(id, { name, base: skinSpriteBase(skin), x, dir: fromLeft ? 1 : -1,
    mode: 'enter', anim: 'walk', animStart: performance.now(), targetX,
    bubbleText: '', bubbleUntil: 0, leaveAt: performance.now() + GUEST_VISIT_MS });
}

function showGuestBubble(g, text) {
  g.bubbleText = text;
  g.bubbleUntil = performance.now() + 4000;
  g.leaveAt = Math.max(g.leaveAt, performance.now() + 6000);
}

window.kat.onPeerEvent((ev) => {
  const g = guests.get(ev.id);
  if (ev.type === 'joined') { if (!g) spawnGuest(ev.id, ev.name, ev.skin); }
  else if (ev.type === 'left') { if (g) { g.mode = 'leave'; g.anim = 'walk'; } }
  else if (ev.type === 'presence') { if (g && g.mode === 'idle') g.anim = GUEST_PRESENCE_ANIM[ev.state] || 'idle'; }
  else if (ev.type === 'wave') { if (g) { const arr = i18n.t('neighbor.greetings'); showGuestBubble(g, Array.isArray(arr) ? arr[0] : '👋'); } }
  else if (ev.type === 'greeting') { if (g) { const arr = i18n.t('neighbor.greetings'); showGuestBubble(g, Array.isArray(arr) ? arr[ev.key % arr.length] : '👋'); } }
});

// 슬래시 명령 카탈로그 — 초기 로드 + openChat 시 갱신
let slashCatalog = [];
window.kat.slashCommands().then((c) => { slashCatalog = c; }).catch(() => {});

function updateChatPlaceholder() {
  const ci = document.getElementById('chatinput');
  if (!ci) return;
  ci.placeholder = ci._skillMode ? i18n.t('skills.mode', { name: ci._skillMode }) : i18n.t('chat.placeholder');
}

window.kat.onLangConfig((lang) => {
  i18n = createI18n(lang);
  updateChatPlaceholder();
});

function getGreetings() {
  const appName = i18n.t('app.name');
  const greetings = i18n.t('bubble.greetings');
  // 배열의 {name} 보간 + 시간 항목 추가
  const resolved = Array.isArray(greetings)
    ? greetings.map((g) => g.replace('{name}', appName))
    : [];
  // 시간 항목을 마지막에 추가
  resolved.push(() => {
    const now = new Date();
    return i18n.t('bubble.time', { h: now.getHours(), m: String(now.getMinutes()).padStart(2, '0') });
  });
  return resolved;
}

const STRETCH_INTERVAL_MS = 50 * 60 * 1000;
const LEAVE_WORK_HOUR = 18;
const LUNCH_HOUR = 12;
const NAP_AFTER_MS = 2 * 60 * 1000;

const SCALE = 1;               // 128px 프레임 → 128px 표시 (SCALE만 바꾸면 전체 크기 조절)
const SIZE = 128 * SCALE;
const JUMP_LIFT = 23 * SCALE;  // 점프 도약 높이(px) — 크기에 비례
const FPS = {
  idle: 4, hover: 6, click: 8, coding: 6, typing: 8, thinking: 5,
  lunch: 5, yawn: 6, nap: 2.5, success: 8, error: 7,
  walk: 6, jump: 8,
};
// 한 번 재생하고 idle로 돌아가는 상태 (나머지는 외부에서 바꿀 때까지 루프)
const ONESHOT = new Set(['click', 'yawn', 'success', 'error', 'jump']);
// 자율 행동(hover/walk/nap 등)이 끼어들면 안 되는 "작업 중" 상태 (walk는 자체가 자율행동이라 제외)
const BUSY = new Set(['coding', 'typing', 'thinking', 'lunch', 'nap', 'success', 'error', 'click', 'yawn', 'jump']);

// --- 스프라이트 로드 -------------------------------------------------------------

const frameCache = {}; // spriteBase -> {state: Image[]}
function framesFor(base) {
  const key = base || 'sprites/';
  if (frameCache[key]) return frameCache[key];
  const set = {};
  for (const [stateName, files] of Object.entries(manifest)) {
    set[stateName] = files.map((f) => {
      const img = new Image();
      // 스킨 프레임이 없으면(미생성/외부 누락) 화이트(루트)로 폴백 — 한 번만.
      // (렌더 루프는 프레임마다 img.complete로 가드하므로 별도 로드 카운터 불필요)
      img.onerror = () => { if (!img._fb) { img._fb = true; img.src = 'sprites/' + f; } };
      img.src = key + f;
      return img;
    });
  }
  frameCache[key] = set;
  return set;
}
// 내 고양이 현재 프레임 세트
let frames = framesFor('sprites/');
window.kat.onSkinConfig((base) => { frames = framesFor(base); });   // 설정에서 스킨 변경 시 즉시 교체

// --- 캔버스 ----------------------------------------------------------------------

const canvas = document.getElementById('cat');
const ctx = canvas.getContext('2d');
const bubble = document.getElementById('bubble');
const bubbleText = document.getElementById('bubbletext'); // 안쪽 스크롤 텍스트 영역
function resizeCanvas() {
  const ratio = window.devicePixelRatio || 1;
  canvas.width = Math.round(window.innerWidth * ratio);
  canvas.height = Math.round(window.innerHeight * ratio);
  canvas.style.width = `${window.innerWidth}px`;
  canvas.style.height = `${window.innerHeight}px`;
  ctx.setTransform(ratio, 0, 0, ratio, 0, 0);
  ctx.imageSmoothingEnabled = true;
  ctx.imageSmoothingQuality = 'high';
}
resizeCanvas();
window.addEventListener('resize', () => resizeCanvas());

// 전폭 전체 높이 창 모드: catX/catY는 창 내 고양이 위치(mutable). DX 상수는 제거.
// 초기값 = 창 중앙 (get-work-area 응답 전 폴백)
let restX = Math.round((window.innerWidth - SIZE) / 2);
let initialPositioned = false;
let screenMetrics = null;
let floorMotion = null;
const FLOOR_MOTION_MS = 420;

function viewport() {
  return { width: window.innerWidth, height: window.innerHeight };
}

function targetRestY(catX = restX) {
  return dockAwareFloorY({
    height: window.innerHeight,
    size: SIZE,
    workArea: screenMetrics && screenMetrics.workArea,
    displayBounds: screenMetrics && screenMetrics.displayBounds,
    dockRect: screenMetrics && screenMetrics.dockRect,
    catX,
    winX: screenMetrics ? screenMetrics.winX : 0,
    winY: screenMetrics ? screenMetrics.winY : 0,
  });
}

function sampleFloorMotion(t, target) {
  if (!floorMotion) return target;
  const p = Math.min(1, (t - floorMotion.start) / floorMotion.dur);
  if (p >= 1) {
    floorMotion = null;
    return target;
  }
  const eased = 1 - Math.pow(1 - p, 3);
  return floorMotion.from + (floorMotion.to - floorMotion.from) * eased;
}

function restY(t = performance.now(), catX = restX, animate = true) {
  const target = targetRestY(catX);
  if (!animate) return target;
  if (floorMotion && Math.abs(floorMotion.to - target) > 1) {
    floorMotion = {
      from: sampleFloorMotion(t, target),
      to: target,
      start: t,
      dur: FLOOR_MOTION_MS,
    };
  }
  return sampleFloorMotion(t, target);
}

// 말풍선/입력창 세로 위치를 스프라이트 크기에 맞춰 고양이 머리 위로 정렬.
// (고양이 윗변 = 창 바닥에서 SIZE+2px) — SCALE을 바꿔도 자동으로 따라온다.
// 256프레임 기준값(말풍선 272 / 입력창 238)을 SIZE 상대식으로 환산.
const BUBBLE_GAP = 16;        // 평소 말풍선 — 고양이 머리 바로 위
const CHATBAR_GAP = 10;       // 입력창 — 스프라이트 윗변(SIZE+2) 위로 띄움
                              // (thinking 생각구름이 입력창과 겹치지 않게)
const chatbarEl = document.getElementById('chatbar');

function catBottomOffset(gap = 0, t = performance.now()) {
  return Math.round(window.innerHeight - restY(t, state ? state.catX : restX) + gap);
}

function updateFloatingUiY(t = performance.now()) {
  const chatBottom = catBottomOffset(CHATBAR_GAP, t);
  if (chatbarEl) chatbarEl.style.bottom = `${chatBottom}px`;
  const chatHeight = chatbarEl ? chatbarEl.offsetHeight : 0;
  bubble.style.bottom = state && state.chatOpen
    ? `${chatBottom + chatHeight + 8}px`
    : `${catBottomOffset(BUBBLE_GAP, t)}px`;
}

function applyScreenMetrics(info) {
  const t = performance.now();
  const before = restY(t);
  screenMetrics = info || null;
  const after = targetRestY(state ? state.catX : restX);
  if (Math.abs(after - before) > 1) {
    floorMotion = { from: before, to: after, start: t, dur: FLOOR_MOTION_MS };
    if (state.mode !== 'grabbed' && state.mode !== 'falling') {
      state.catY = before;
      state.fallStartY = before;
      setAnim('jump');
    }
  }
  if (info && info.workArea) {
    const wa = info.workArea;
    restX = Math.round(wa.x + wa.width * 0.7 - info.winX - SIZE / 2);
    restX = Math.max(0, Math.min(restX, window.innerWidth - SIZE));
    if (!initialPositioned) {
      state.catX = restX;
      initialPositioned = true;
    } else if (state.mode !== 'grabbed') {
      state.catX = Math.max(0, Math.min(state.catX, window.innerWidth - SIZE));
    }
  }
  updateFloatingUiY(t);
}

// --- 상태 ------------------------------------------------------------------------

const state = {
  anim: 'idle',
  animStart: performance.now(),
  autoRevertAt: Infinity,
  mode: 'idle', // idle | walk | grabbed | falling
  modeUntil: 0,
  dir: 1,
  squashUntil: 0,
  fallEased: 0, // 낙하 진행도(eased). 놓은 위치→바닥으로 보간해 착지 스왑 점프 제거
  catX: restX, // 창 내 고양이 x 위치. 산책/드래그는 이 값을 갱신.
  catY: restY(), // 창 내 고양이 y 위치. 평소엔 바닥, 드래그 중엔 커서를 따라감.
  fallStartY: restY(),
  cursor: { x: 0, y: 0, winX: 0, winY: 0 },
  grabOffset: { x: 0, y: 0 },
  pressed: null,
  hovering: false,
  dragVx: 0,
  lastStretchAt: performance.now(),
  cheeredLeaveToday: false,
  lunchedToday: false,
  bubbleTimer: null,
  lastInteraction: performance.now(),
  nextAutoFx: performance.now() + 25000,
  chatOpen: false,
  chatSeq: 0, // 보낸 턴 식별자 — 닫힘/새질문 뒤 늦게 온 응답(stale)을 버리기 위함
  streamSeq: -1, // 현재 스트리밍 중인 턴 (첫 델타에서 말풍선 초기화 판단)
  summaryActive: false, // 클립보드 요약 진행 중 — 폴러/자율행동이 응답 애니를 덮지 않게
};

const sounds = createSounds({ enabled: true }); // 기본 on, main의 sound-config로 갱신
window.kat.onSoundConfig((cfg) => sounds.setEnabled(!!(cfg && cfg.enabled)));
window.kat.onBgmPlay((preset) => sounds.playBgm(preset));
window.kat.onBgmStop(() => sounds.stopBgm());
window.kat.getWorkArea().then(applyScreenMetrics).catch(() => updateFloatingUiY());
window.kat.onScreenMetrics(applyScreenMetrics);
updateFloatingUiY();

function setAnim(name, revertMs) {
  if (!frames[name] || !frames[name].length) name = 'idle';
  if (state.anim === name) return;
  state.anim = name;
  state.animStart = performance.now();
  state.autoRevertAt = revertMs ? state.animStart + revertMs : Infinity;
  window.kat.reportAnim?.(name);
  if (BUSY.has(name) && state.mode === 'walk') state.mode = 'idle';
}

// AgentStatusBridge: 메인 프로세스(데모 메뉴 → 추후 실제 에이전트)에서 상태 수신
function setState(name) {
  if (name === 'clicked') name = 'click';
  if (name === 'idle') {
    state.anim = 'idle';
    state.animStart = performance.now();
    state.autoRevertAt = Infinity;
    return;
  }
  state.lastInteraction = performance.now();
  setAnim(name);
}

function speak(msg, ms = 3500) {
  bubbleText.textContent = typeof msg === 'function' ? msg() : msg;
  bubbleText.scrollTop = 0;
  bubble.classList.add('show');
  clearTimeout(state.bubbleTimer);
  state.bubbleTimer = setTimeout(() => bubble.classList.remove('show'), ms);
}

let revealTimer = null;
function speakReveal(full, cps = 28, onComplete) {
  // 게이팅은 호출부(onChatReply는 chatOpen+seq, closeChat은 타이머 정리)에서 담당.
  // 클립보드 요약은 입력창이 닫힌 상태에서도 응답을 보여줘야 하므로 여기선 막지 않는다.
  clearInterval(revealTimer);
  clearTimeout(state.bubbleTimer);
  const text = typeof full === 'function' ? full() : String(full);
  bubble.classList.add('show');
  let i = 0;
  revealTimer = setInterval(() => {
    i++;
    bubbleText.textContent = text.slice(0, i);
    bubbleText.scrollTop = bubbleText.scrollHeight; // 길어지면 최신 글자를 따라 스크롤
    if (i >= text.length) {
      clearInterval(revealTimer);
      setAnim('success'); // 다 보여주면 잠깐 만세
      state.bubbleTimer = setTimeout(() => bubble.classList.remove('show'), 5000);
      if (onComplete) onComplete();
    }
  }, 1000 / cps);
}

const chatbar = document.getElementById('chatbar');
const chatinput = document.getElementById('chatinput');

function openChat() {
  sounds.play('chirp');
  state.chatOpen = true;
  state.lastInteraction = performance.now();
  state.mode = 'idle'; // 채팅 중엔 산책 금지 — 입력창이 움직이면 안 된다
  if (state.anim === 'nap') setState('idle');
  chatbar.classList.add('show');
  // 채팅 중엔 답변 말풍선을 입력창 위로 올려, 입력창·고양이와 안 겹치게.
  updateFloatingUiY();
  window.kat.setIgnoreMouse(false); // 입력창 클릭/포커스 받도록
  // 스킬 토글 반영을 위해 채팅 열 때 카탈로그 갱신
  window.kat.slashCommands().then((c) => { slashCatalog = c; }).catch(() => {});
  // 이미 열려 있어도 고양이를 다시 클릭하면 포커스를 다시 가져온다(다른 앱에 뺏겼을 때 복구).
  setTimeout(() => { window.kat.focusWindow?.(); chatinput.focus(); }, 0);
}

function closeChat() {
  if (!state.chatOpen) return;
  state.chatOpen = false;
  state.chatSeq++; // 진행 중이던 응답 무효화
  clearInterval(revealTimer);
  clearTimeout(state.bubbleTimer);
  bubble.classList.remove('show');
  chatbar.classList.remove('show');
  updateFloatingUiY(); // 평소 위치로 복원
  chatinput.value = '';
  closeSlashMenu(); // 드롭다운도 닫기
  // 스킬 모드 해제 — placeholder 복원
  if (chatinput._skillMode) {
    chatinput._skillMode = null;
    updateChatPlaceholder();
  }
  chatinput.blur();
  window.kat.resetChat();
}

// === 슬래시 명령 자동완성 드롭다운 ===

const slashmenu = document.getElementById('slashmenu');
let slashSelected = -1; // 현재 선택된 드롭다운 인덱스

function esc(s) {
  return String(s)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

function isSlashMenuOpen() {
  return slashmenu.classList.contains('open');
}

function closeSlashMenu() {
  slashmenu.classList.remove('open');
  slashmenu.innerHTML = '';
  slashSelected = -1;
}

function renderSlashMenu(items) {
  if (!items || items.length === 0) { closeSlashMenu(); return; }
  slashSelected = -1;
  slashmenu.innerHTML = items.map((item, idx) =>
    `<div class="slash-item" data-idx="${idx}">` +
    `<span class="slash-name">/${esc(item.name)}</span>` +
    `<span class="slash-desc">${esc(item.desc || '')}</span>` +
    `</div>`
  ).join('');
  slashmenu.classList.add('open');
  // 클릭으로 선택
  slashmenu.querySelectorAll('.slash-item').forEach((el, idx) => {
    el.addEventListener('mousedown', (e) => {
      e.preventDefault(); // input blur 방지
      const item = items[idx];
      if (item) {
        chatinput.value = '/' + item.name + ' ';
        closeSlashMenu();
        chatinput.focus();
      }
    });
  });
}

function updateSlashMenuSelected(items) {
  slashmenu.querySelectorAll('.slash-item').forEach((el, idx) => {
    el.classList.toggle('selected', idx === slashSelected);
    if (idx === slashSelected) el.scrollIntoView({ block: 'nearest' });
  });
}

function getCurrentSlashItems() {
  const val = chatinput.value;
  if (!val.startsWith('/')) return [];
  const prefix = val.slice(1).split(' ')[0];
  return matchCommands(prefix, slashCatalog);
}

// input 이벤트: 명령어 '이름' 입력 중(슬래시 + 아직 공백 없음)에만 드롭다운.
// 공백 이후(=인자 입력)엔 닫아서 Enter가 재완성이 아니라 실행으로 가게 한다(/skin black 등).
chatinput.addEventListener('input', () => {
  const val = chatinput.value;
  if (val.startsWith('/') && !val.slice(1).includes(' ')) {
    renderSlashMenu(getCurrentSlashItems());
  } else {
    closeSlashMenu();
  }
});

chatinput.addEventListener('keydown', (e) => {
  e.stopPropagation();

  // 드롭다운 열려 있을 때 키 처리
  if (isSlashMenuOpen()) {
    const items = getCurrentSlashItems();
    if (e.key === 'ArrowDown') {
      e.preventDefault();
      slashSelected = Math.min(slashSelected + 1, items.length - 1);
      updateSlashMenuSelected(items);
      return;
    }
    if (e.key === 'ArrowUp') {
      e.preventDefault();
      slashSelected = Math.max(slashSelected - 1, -1);
      updateSlashMenuSelected(items);
      return;
    }
    if (e.key === 'Tab' || e.key === 'Enter') {
      e.preventDefault();
      const item = items[slashSelected >= 0 ? slashSelected : 0];
      if (item) {
        chatinput.value = '/' + item.name + ' ';
        closeSlashMenu();
      }
      return;
    }
    if (e.key === 'Escape') {
      e.preventDefault();
      closeSlashMenu();
      return;
    }
    return; // 드롭다운 열린 상태에서 다른 키는 그냥 통과 (input 이벤트가 갱신)
  }

  // 드롭다운 닫혀 있을 때 Enter 처리
  if (e.key === 'Enter') {
    const val = chatinput.value.trim();
    if (!val) return;

    const parsed = parseSlash(val);
    if (!parsed) {
      // 일반 채팅 전송
      window.kat.sendChat(val, ++state.chatSeq);
      chatinput.value = '';
      return;
    }

    const { cmd, args } = parsed;

    // /help — 렌더러 로컬 처리
    if (cmd === 'help') {
      // speak()는 textContent라 이스케이프 불필요(이중 이스케이프 방지)
      const lines = slashCatalog.map((c) => `/${c.name} — ${c.desc || ''}`).join('\n');
      speak(i18n.t('slash.help') + '\n' + lines);
      chatinput.value = '';
      return;
    }

    // /reset — 렌더러 로컬 처리
    if (cmd === 'reset') {
      window.kat.resetChat();
      speak(i18n.t('slash.reset'));
      chatinput.value = '';
      return;
    }

    // 그 외 — main 라우터로 전송
    window.kat.runSlash({ cmd, args });
    chatinput.value = '';
    return;
  }

  if (e.key === 'Escape') {
    closeChat();
  }
});

// 바깥 클릭으로 닫기 (입력창·고양이 몸 밖)
window.addEventListener('mousedown', (e) => {
  if (!state.chatOpen) return;
  const onBar = chatbar.contains(e.target);
  const onBubble = bubble.contains(e.target);
  const onCat = inCat(e.clientX, e.clientY);
  if (!onBar && !onBubble && !onCat) closeChat();
}, true);

// --- 그리기 ----------------------------------------------------------------------

function currentFrame(t) {
  const list = frames[state.anim];
  // typing은 매끈한 시간 기반 루프로 손이 흐르게 한다(키마다 프레임을 묶으면 사람 타이핑
  // 속도에선 프레임이 띄엄띄엄 바뀌어 끊겨 보였다). "멈추면 정지"는 externalDrive의
  // typingUntil 게이트가 담당 — 키를 안 치면 TYPING_HOLD 후 typing이 풀려 idle로 복귀한다.
  const fps = FPS[state.anim] || 6;
  const i = Math.floor(((t - state.animStart) / 1000) * fps);
  if (ONESHOT.has(state.anim) && i >= list.length) return null; // 재생 끝
  return list[i % list.length];
}

function dangleFrame(t) {
  // 드래그 속도에 따라 스윙 프레임 선택: 1=오른쪽으로 끌 때(하체가 왼쪽으로 뒤처짐),
  // 3=왼쪽으로 끌 때, 가만히 들고 있으면 0(축 늘어짐)↔2(최대 스트레치) 느린 출렁임
  const v = state.dragVx;
  if (v > 2.5) return frames.dragging[1];
  if (v < -2.5) return frames.dragging[3];
  return frames.dragging[Math.floor(t / 420) % 2 === 0 ? 0 : 2];
}

function renderedCatY(t = performance.now()) {
  const floor = restY(t, state.catX);
  if (state.mode === 'grabbed') return state.catY;
  if (state.mode === 'falling') return fallY({ startY: state.fallStartY, floorY: floor, eased: state.fallEased });
  return floor;
}

function draw(t) {
  ctx.clearRect(0, 0, window.innerWidth, window.innerHeight);

  const grabbed = state.mode === 'grabbed';
  const falling = state.mode === 'falling';
  let img;
  if (grabbed && frames.dragging) img = dangleFrame(t);
  else if (falling && frames.dragging) img = frames.dragging[0];
  else img = currentFrame(t);
  if (!img || !img.complete) return;

  // 점프 상하 궤적 — 스프라이트는 자세만 그리고, 실제 도약은 코드로 입힌다
  let jumpLift = 0;
  if (state.anim === 'jump' && frames.jump) {
    const dur = (frames.jump.length / (FPS.jump || 8)) * 1000;
    const p = Math.min(1, (t - state.animStart) / dur);
    jumpLift = -Math.sin(p * Math.PI) * JUMP_LIFT;
  }
  const liftRatio = Math.min(1, -jumpLift / JUMP_LIFT);

  // 바닥 그림자 (공중에 뜨면 옅고 작게)
  const catCx = state.catX + SIZE / 2; // 고양이 중앙 x (창 로컬)
  const platformY = restY(t, state.catX);
  if (!grabbed && !falling) {
    ctx.fillStyle = `rgba(20, 24, 40, ${0.18 * (1 - liftRatio * 0.7)})`;
    ctx.beginPath();
    ctx.ellipse(catCx, platformY + SIZE - 5 * SCALE,
      SIZE * 0.3 * (1 - liftRatio * 0.35), 4.5 * SCALE * (1 - liftRatio * 0.35), 0, 0, Math.PI * 2);
    ctx.fill();
  }

  // 변형: 착지 찌부, 걸을 때 가벼운 통통, 매달리면 관성 기울기
  let sx = 1, sy = 1;
  if (t < state.squashUntil) { sx = 1.1; sy = 0.86; }
  // walk 스프라이트가 바운스를 직접 그리므로 코드 통통은 살짝만 (사뿐사뿐)
  const bob = state.mode === 'walk' ? -Math.abs(Math.sin(t / 160)) * 3 : 0;
  // walk 스프라이트는 오른쪽을 보고 있음(native) → 왼쪽(dir=-1)으로 갈 때만 좌우 반전
  const flip = state.mode === 'walk' && state.dir === -1 ? -1 : 1;
  // 매달림: 핀치 포인트(상단 중앙)를 축으로 드래그 반대 방향으로 살짝 기운다
  const swing = grabbed ? Math.max(-0.3, Math.min(0.3, -state.dragVx * 0.025)) : 0;

  const drawDY = renderedCatY(t);
  ctx.save();
  if (grabbed || falling) {
    const pivotY = drawDY + DEFAULT_PIN_OFFSET_Y; // 스프라이트 핀치 포인트(위 정렬)
    ctx.translate(catCx, pivotY);
    ctx.rotate(swing);
    ctx.translate(-catCx, -pivotY);
  } else {
    const bottom = platformY + SIZE;
    ctx.translate(catCx, bottom);
    ctx.scale(sx * flip, sy);
    ctx.translate(-catCx, -bottom);
  }
  ctx.drawImage(img, state.catX, drawDY + bob + jumpLift, SIZE, SIZE);
  ctx.restore();

  // 말풍선·입력창 가로 위치를 고양이 중앙에 맞춘다.
  // CSS transform(translateX -50% + 팝인 효과)은 그대로 두고 left만 갱신
  const bx = state.catX + SIZE / 2;
  bubble.style.left = `${bx}px`;
  if (chatbarEl) chatbarEl.style.left = `${bx}px`;
  updateFloatingUiY(t);

  // 손님 고양이 렌더 (피어 이벤트가 없으면 guests는 빈 Map → no-op)
  for (const [id, g] of guests) {
    const speed = 2.4;
    if (g.mode === 'enter') {
      if (Math.abs(g.x - g.targetX) <= speed) { g.x = g.targetX; g.mode = 'idle'; g.anim = 'idle'; g.dir = g.x < state.catX ? 1 : -1; }
      else { g.x += Math.sign(g.targetX - g.x) * speed; }
    } else if (g.mode === 'idle') {
      if (t > g.leaveAt) { g.mode = 'leave'; g.anim = 'walk'; g.dir = g.x < window.innerWidth / 2 ? -1 : 1; }
    } else if (g.mode === 'leave') {
      g.x += g.dir * speed;
      if (g.x < -SIZE || g.x > window.innerWidth) { guests.delete(id); continue; }
    }
    const gf = framesFor(g.base)[g.anim] || framesFor(g.base).idle;
    if (!gf || !gf.length) continue;
    const gi = Math.floor(((t - g.animStart) / 1000) * (FPS[g.anim] || 6)) % gf.length;
    const gimg = gf[gi];
    if (gimg && gimg.complete) {
      ctx.save();
      if (g.dir === -1) { ctx.translate(g.x + SIZE / 2, 0); ctx.scale(-1, 1); ctx.translate(-(g.x + SIZE / 2), 0); }
      const guestY = restY(t, g.x, false);
      ctx.drawImage(gimg, g.x, guestY, SIZE, SIZE);
      ctx.restore();
      drawGuestLabel(g, guestY);
      if (g.bubbleText && t < g.bubbleUntil) drawGuestBubble(g, guestY);
    }
  }

  // 손님이 모였을 때만 내 고양이도 이름표(평소엔 깔끔)
  if (guests.size > 0 && myCatName) {
    drawLabelAt(state.catX + SIZE / 2, platformY - 4, myCatName);
  }
}

// --- 행동 루프 (3D 버전과 동일한 리추얼/상태 로직) -----------------------------------

function pickNextMode(t) {
  if (state.chatOpen || state.summaryActive) { state.mode = 'idle'; state.modeUntil = t + 1500; return; }
  if (state.anim !== 'idle' && state.anim !== 'hover') { state.modeUntil = t + 2000; return; }
  if (Math.random() < 0.35) {
    state.mode = 'walk';
    state.dir = Math.random() < 0.5 ? 1 : -1;
    state.modeUntil = t + 1500 + Math.random() * 3000;
  } else {
    state.mode = 'idle';
    state.modeUntil = t + 3000 + Math.random() * 5000;
  }
}

function tick(t) {
  // 원샷 종료/시한부 상태 → idle 복귀
  if (ONESHOT.has(state.anim) && currentFrame(t) === null) setState('idle');
  if (t > state.autoRevertAt) setState('idle');

  // 외부 구동(에이전트 브리지/유저 타이핑/프로세스 폴러)이 최우선
  const drive = state.mode === 'grabbed' ? null : externalDrive(t);
  if (drive) {
    setAnim(drive);
  } else if (lastDrive && state.anim === lastDrive && !ONESHOT.has(state.anim)) {
    setAnim('idle'); // 외부 구동이 풀리면 평소로
  }
  lastDrive = drive;

  if (!drive) {
    if (state.mode === 'walk') {
      // 걷는 중엔 전용 walk 스프라이트(사뿐사뿐)
      if (state.anim === 'idle' || state.anim === 'hover') setAnim('walk');
    } else {
      if (state.anim === 'walk') setAnim('idle'); // 멈추면 평소로

      // hover: 커서가 고양이 위에 있고 한가할 때 (시트 HOVER 상태)
      if (!BUSY.has(state.anim) && state.mode !== 'grabbed') {
        if (state.hovering && state.anim === 'idle') setAnim('hover');
        if (!state.hovering && state.anim === 'hover') setAnim('idle');
      }

      // 자율 행동: 가끔 하품 또는 점프, 오래 방치하면 낮잠 (채팅 중엔 '듣는' 자세 유지)
      if (state.anim === 'idle' && state.mode === 'idle' && !state.chatOpen) {
        if (t > state.nextAutoFx) {
          state.nextAutoFx = t + 30000 + Math.random() * 40000;
          const r = Math.random();
          if (r < 0.33) setAnim('yawn');
          else if (r < 0.66) setAnim('jump');
        }
        if (t - state.lastInteraction > NAP_AFTER_MS) setAnim('nap');
      }
    }
  }

  if (state.mode === 'walk') {
    // 창 고정, state.catX만 이동. 경계에 닿으면 방향 반전.
    const newCatX = state.catX + state.dir * 1.6;
    if (newCatX <= 0 || newCatX >= window.innerWidth - SIZE) {
      state.dir = -state.dir; // 경계 반전
    }
    state.catX = Math.max(0, Math.min(Math.round(state.catX + state.dir * 1.6), window.innerWidth - SIZE));
    if (t > state.modeUntil) pickNextMode(t);
  } else if (state.mode === 'idle') {
    if (t > state.modeUntil) pickNextMode(t);
  }

  // 리추얼 (채팅/요약 중엔 끼어들지 않음 — 조건은 유지돼 끝나면 곧 발동)
  const now = new Date();
  if (!state.chatOpen && !state.summaryActive) {
    if (t - state.lastStretchAt > STRETCH_INTERVAL_MS) {
      state.lastStretchAt = t;
      setAnim('yawn');
      speak(i18n.t('ritual.stretch'), 6000);
    }
    if (now.getHours() === LUNCH_HOUR && !state.lunchedToday) {
      state.lunchedToday = true;
      setAnim('lunch', 90 * 1000);
      speak(i18n.t('ritual.lunch'), 8000);
    }
    if (now.getHours() === LEAVE_WORK_HOUR && !state.cheeredLeaveToday) {
      state.cheeredLeaveToday = true;
      setAnim('success');
      speak(i18n.t('ritual.leave'), 8000);
    }
  }
  if (now.getHours() < LUNCH_HOUR) state.lunchedToday = false;
  if (now.getHours() < LEAVE_WORK_HOUR) state.cheeredLeaveToday = false;

  draw(t);
  requestAnimationFrame(tick);
}

// --- 입력/IPC ----------------------------------------------------------------------

function inCat(x, y) {
  // 인셋은 256프레임 기준 24/40 → 크기에 비례(12/20 * SCALE)
  const y0 = renderedCatY();
  return x > state.catX + 12 * SCALE
    && x < state.catX + SIZE - 12 * SCALE
    && y > y0 + 20 * SCALE
    && y < y0 + SIZE;
}

function guestAt(x, y) { // 창 로컬 좌표
  for (const [id, g] of guests) {
    const y0 = restY(performance.now(), g.x, false);
    if (g.mode !== 'leave'
      && x >= g.x
      && x <= g.x + SIZE
      && y >= y0 + 20 * SCALE
      && y <= y0 + SIZE) return id;
  }
  return null;
}

function rectContains(el, x, y, pad = 0) {
  if (!el) return false;
  const r = el.getBoundingClientRect();
  return x >= r.left - pad && x <= r.right + pad && y >= r.top - pad && y <= r.bottom + pad;
}

// 창이 마우스를 무시하면 안 되는 영역: 고양이 몸 / 손님 고양이 / 채팅 열림 / 보이는 말풍선 위
function overInteractive(x, y) {
  if (inCat(x, y)) return true;
  if (guestAt(x, y) !== null) return true;
  if (state.chatOpen && rectContains(chatbarEl, x, y, 8)) return true; // 입력창만 클릭 가능해야 함
  if (bubble.classList.contains('show')) {
    if (rectContains(bubble, x, y)) return true;
  }
  return false;
}

// 말풍선을 누르면 입력창이 열리고 포커스 (응답을 보고 바로 이어서 물어보기)
bubble.addEventListener('click', () => openChat());

canvas.addEventListener('mousedown', (e) => {
  if (!inCat(e.clientX, e.clientY)) return;
  if (e.button === 2) return;
  state.lastInteraction = performance.now();
  if (state.anim === 'nap') {
    setState('idle');
    speak(i18n.t('bubble.wake'), 2000);
  }
  state.pressed = { x: state.cursor.x, y: state.cursor.y, moved: false };
  // 잡는 순간 목덜미(스프라이트 상단 중앙 핀치 포인트)가 커서에 붙는다
  // grabOffset.x = 커서를 잡을 때 catX 중앙에서의 오프셋 (창 로컬 x)
  state.catY = renderedCatY();
  state.grabOffset = { x: state.catX + SIZE / 2, y: state.catY + DEFAULT_PIN_OFFSET_Y };
});

window.addEventListener('mouseup', async (e) => {
  if (!state.pressed) return;
  const wasDrag = state.pressed.moved;
  state.pressed = null;
  state.lastInteraction = performance.now();
  if (state.mode === 'grabbed') {
    await fallToBottom();
  } else if (!wasDrag) {
    const localX = e.clientX;
    if (inCat(localX, e.clientY)) {
      openChat(); // 짧은 클릭 → 채팅 입력창
    } else {
      const gid = guestAt(localX, e.clientY);
      if (gid) {
        window.kat.neighborWave(gid);
        const g = guests.get(gid);
        if (g) {
          const arr = i18n.t('neighbor.greetings');
          showGuestBubble(g, Array.isArray(arr) ? arr[0] : '👋');
        }
      }
    }
  }
});

canvas.addEventListener('contextmenu', (e) => {
  e.preventDefault();
  if (inCat(e.clientX, e.clientY)) window.kat.showContextMenu();
});

let mouseIgnored = false;
window.kat.onCursor((c) => {
  // 드래그 가로 속도 (지수 평활) — 매달림 스윙 프레임/기울기에 사용
  state.dragVx = state.dragVx * 0.65 + (c.x - state.cursor.x) * 0.35;
  state.cursor = c;
  const lx = c.x - c.winX, ly = c.y - c.winY;
  state.hovering = inCat(lx, ly);
  const shouldIgnore = !overInteractive(lx, ly) && !state.pressed && state.mode !== 'grabbed';
  if (shouldIgnore !== mouseIgnored) {
    mouseIgnored = shouldIgnore;
    window.kat.setIgnoreMouse(shouldIgnore);
  }
  if (state.pressed) {
    const dist = Math.hypot(c.x - state.pressed.x, c.y - state.pressed.y);
    if (dist > 6) {
      state.pressed.moved = true;
      if (state.mode !== 'grabbed') sounds.play('pluck'); // 잡는 순간 1회
      state.mode = 'grabbed';
    }
    if (state.mode === 'grabbed') {
      // 창은 고정, 고양이 좌표만 이동. 핀치 포인트를 커서에 맞춤(상단 중앙).
      const next = clampDraggedCat({
        cursorLocal: { x: lx, y: ly },
        size: SIZE,
        viewport: viewport(),
        pinOffsetY: DEFAULT_PIN_OFFSET_Y,
      });
      state.catX = next.x;
      state.catY = next.y;
    }
  }
});

// --- 외부 구동 레이어: AgentStatusBridge + 글로벌 키보드 + 프로세스 폴러 -------------

const SOURCE_LABEL = {
  cursor: 'Cursor',
  claude: 'Claude Code',
  codex: 'Codex',
  'codex-cli': 'Codex CLI',
  'codex-app': 'Codex App',
  antigravity: 'Antigravity',
  gemini: 'Gemini',
  kiro: 'Kiro',
  get demo() { return i18n.t('source.demo'); },
};
function getStateBubble(st) { return i18n.t('state.' + st); }
const AGENT_ANIM = { waiting: 'hover', clicked: 'click' }; // 브리지 상태 → 시트 애니 매핑
const AGENT_TTL = 90 * 1000;  // 이벤트 갱신 없으면 자동 해제
const TYPING_HOLD = 650;      // 마지막 키 입력 후 typing 유지 — 손을 멈추면 곧바로 그만 친다
const PROC_CPU_BUSY = 10;     // 폴러: 이 CPU% 이상이면 작업 중으로 간주

const agentDrive = { state: 'idle', source: null, until: 0 };
let typingUntil = 0;
let agentProcs = {};
let lastDrive = null;
let lastBubbleKey = '';
let lastBubbleAt = 0;

function agentBubble(source, st, message, t) {
  const key = `${source}:${st}`;
  if (!message && key === lastBubbleKey && t - lastBubbleAt < 15000) return;
  lastBubbleKey = key;
  lastBubbleAt = t;
  const stText = getStateBubble(st);
  speak(message || `${SOURCE_LABEL[source] || source}: ${stText !== 'state.' + st ? stText : st}`);
}

window.kat.onAgentEvent(({ state: st, source, message }) => {
  const t = performance.now();
  if (st === 'clicked') st = 'click';
  state.lastInteraction = t; // 에이전트가 일하는 동안엔 낮잠 안 잔다 (자고 있었다면 깬다)
  if (st === 'idle') {
    agentDrive.state = 'idle';
    agentDrive.source = null;
    setState('idle');
    return;
  }
  agentDrive.state = st;
  agentDrive.source = source;
  const anim = AGENT_ANIM[st] || st;
  agentDrive.until = t + (ONESHOT.has(anim) ? 2000 : AGENT_TTL);
  // 유저가 타이핑 중이면 지속 상태는 타이핑이 끝난 뒤 externalDrive가 적용 (원샷은 즉시)
  if (ONESHOT.has(anim) || t >= typingUntil) setAnim(anim);
  if (st === 'success') sounds.play('success');
  else if (st === 'error') sounds.play('error');
  // 명시적 message(업데이트 알림 등)는 상태와 무관하게 항상 표시. message 없으면 state.* 번역이
  // 있는 상태만 말풍선(hover/click 같은 잡상태가 말풍선 띄우는 것 방지).
  const stBubble = getStateBubble(st);
  if (message || stBubble !== 'state.' + st) agentBubble(source, st, message, t);
});
window.kat.onUserTyping(() => {
  if (state.chatOpen) return; // 채팅 입력 중엔 따라치지 않고 '듣는' 자세 유지
  const t = performance.now();
  typingUntil = t + TYPING_HOLD; // 이 시점까지 typing 유지(매끈한 루프), 지나면 idle 복귀
  state.lastInteraction = t;     // 타이핑은 상호작용 — 낮잠 타이머 리셋(자고 있었다면 깬다)
});
window.kat.onAgentProcs((cpu) => { agentProcs = cpu || {}; });

window.kat.onChatThinking(() => {
  state.summaryActive = false; // 채팅이 요약을 대체
  state.streamSeq = -1;
  state.lastInteraction = performance.now();
  setAnim('thinking');
});
window.kat.onChatDelta(({ text, seq }) => {
  if (!state.chatOpen || seq !== state.chatSeq) return;
  if (seq !== state.streamSeq) {
    // 이 턴의 첫 토큰 — 생성되는 대로 보여주기 시작
    state.streamSeq = seq;
    state.lastInteraction = performance.now();
    setAnim('coding');
    clearInterval(revealTimer);
    clearTimeout(state.bubbleTimer);
    bubbleText.textContent = '';
    bubble.classList.add('show');
  }
  bubbleText.textContent += text;
  bubbleText.scrollTop = bubbleText.scrollHeight;
});
window.kat.onChatReply(({ text, seq }) => {
  if (!state.chatOpen || seq !== state.chatSeq) return; // 닫혔거나 새 질문으로 바뀐 뒤 온 응답 무시
  state.lastInteraction = performance.now();
  bubbleText.textContent = text; // 스트림 누락 대비 최종본 확정
  bubbleText.scrollTop = bubbleText.scrollHeight;
  bubble.classList.add('show');
  setAnim('success'); // 다 받으면 잠깐 만세
  clearTimeout(state.bubbleTimer);
  state.bubbleTimer = setTimeout(() => bubble.classList.remove('show'), 5000);
});
window.kat.onChatError(({ msg, seq }) => {
  if (!state.chatOpen || seq !== state.chatSeq) return;
  setAnim('error');
  speak(msg, 5000);
});

// 스킬 원샷 실행 결과 (clipboard/none 모드) — 입력창과 무관한 단발 응답
window.kat.onSkillThinking(() => {
  state.summaryActive = true;
  state.lastInteraction = performance.now();
  setAnim('thinking');
});
window.kat.onSkillReply((text) => {
  if (!state.summaryActive) return; // 채팅 등으로 대체된 뒤 늦게 온 응답 무시
  state.lastInteraction = performance.now();
  setAnim('coding');
  speakReveal(text, 28, () => { state.summaryActive = false; });
});
window.kat.onSkillError((msg) => {
  if (!state.summaryActive) return;
  state.summaryActive = false;
  setAnim('error');
  speak(msg, 5000);
});

// 스킬 prompt 모드 활성화 — 채팅창 열고 스킬 모드 표시
window.kat.onSkillActive(({ name }) => {
  openChat();
  // 입력창 placeholder에 스킬 모드 표시
  if (chatinput) {
    // 채팅 닫힐 때 placeholder 복원을 위해 원래 값 저장
    chatinput._skillMode = name;
    updateChatPlaceholder();
  }
});

// 매 틱 외부 구동 애니 결정. null이면 자율 행동(hover/yawn/nap/walk)에게 양보
function externalDrive(t) {
  // 채팅 중엔 onChat* 핸들러가 setAnim으로 애니를 통제한다. 폴러/자율행동이 끼어들지 않게,
  // 현재가 작업 상태(thinking/coding/success 등)면 그대로 유지하고 아니면 양보한다.
  if (state.chatOpen || state.summaryActive) return BUSY.has(state.anim) ? state.anim : null;
  // 유저의 물리적 타이핑이 최우선 — "내가 칠 때는 타이핑 모드" (원샷 재생은 예외)
  if (t < typingUntil && !ONESHOT.has(state.anim)) return 'typing';
  if (agentDrive.state !== 'idle') {
    if (t > agentDrive.until) {
      agentDrive.state = 'idle';
      agentDrive.source = null;
    } else {
      const anim = AGENT_ANIM[agentDrive.state] || agentDrive.state;
      return ONESHOT.has(anim) ? null : anim; // 원샷은 이벤트 시점 setAnim으로 충분
    }
  }
  const busy = Object.entries(agentProcs)
    .filter(([, c]) => c >= PROC_CPU_BUSY)
    .sort((a, b) => b[1] - a[1])[0];
  if (busy) {
    agentBubble(busy[0], 'coding', null, t);
    return 'coding';
  }
  return null;
}

window.__setState = setState; // 디버그/캡처용
window.__grab = (vx = 0, y = 0) => { state.mode = 'grabbed'; state.dragVx = vx; state.catY = y; }; // 캡처용

async function fallToBottom() {
  state.mode = 'falling';
  state.fallEased = 0;
  state.fallStartY = state.catY;
  const floor = restY(performance.now(), state.catX);
  const visualDrop = Math.max(0, floor - state.fallStartY);
  const dur = Math.min(450, Math.max(120, visualDrop * 0.6));
  const t0 = performance.now();
  return new Promise((resolve) => {
    function step(t) {
      const p = Math.min(1, (t - t0) / dur);
      const eased = p * p;
      state.fallEased = eased;
      state.catY = fallY({ startY: state.fallStartY, floorY: floor, eased });
      if (p < 1) {
        requestAnimationFrame(step);
      } else {
        state.fallEased = 1;
        state.catY = floor;
        state.fallStartY = floor;
        state.squashUntil = performance.now() + 130;
        sounds.play('land');
        state.mode = 'idle';
        state.modeUntil = performance.now() + 2000;
        resolve();
      }
    }
    requestAnimationFrame(step);
  });
}

// --- 손님 고양이 보조 함수 -------------------------------------------------------------

function roundRect(x, y, w, h, r) {
  ctx.beginPath();
  ctx.moveTo(x + r, y); ctx.arcTo(x + w, y, x + w, y + h, r); ctx.arcTo(x + w, y + h, x, y + h, r);
  ctx.arcTo(x, y + h, x, y, r); ctx.arcTo(x, y, x + w, y, r); ctx.closePath();
}
function drawLabelAt(cx, ly, text) {
  ctx.font = '11px -apple-system, sans-serif'; ctx.textAlign = 'center';
  const w = ctx.measureText(text).width + 12;
  ctx.fillStyle = 'rgba(20,24,40,0.72)';
  roundRect(cx - w / 2, ly - 14, w, 16, 7); ctx.fill();
  ctx.fillStyle = '#fff'; ctx.fillText(text, cx, ly - 2);
}
function drawGuestLabel(g, floor = restY(performance.now(), g.x, false)) {
  drawLabelAt(g.x + SIZE / 2, floor - 4, g.name);
}
function drawGuestBubble(g, floor = restY(performance.now(), g.x, false)) {
  ctx.font = '12px -apple-system, sans-serif'; ctx.textAlign = 'center';
  const cx = g.x + SIZE / 2, by = floor - 22;
  const w = ctx.measureText(g.bubbleText).width + 18;
  ctx.fillStyle = '#fffef8'; roundRect(cx - w / 2, by - 22, w, 22, 9); ctx.fill();
  ctx.fillStyle = '#222'; ctx.fillText(g.bubbleText, cx, by - 7);
}

// --- 시작 -----------------------------------------------------------------------------

window.kat.reportAnim?.('idle'); // /anim 진단 엔드포인트가 부팅 직후부터 정확하도록
requestAnimationFrame(tick);
updateChatPlaceholder();
setTimeout(() => speak(i18n.t('bubble.intro').replace('{name}', i18n.t('app.name'))), 800);
