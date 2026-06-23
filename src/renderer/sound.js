// 신스 효과음. 순수 로직(레시피/스로틀/enabled)과 Web Audio 호출을 분리.
// 외부 에셋 없음 — OscillatorNode + GainNode로 절차 생성.
const RECIPES = {
  chirp:   { type: 'triangle', seq: [[660, 0], [990, 0.045]], dur: 0.09, gain: 1.0 },
  pluck:   { type: 'square',   seq: [[440, 0]],               dur: 0.07, gain: 0.7 },
  land:    { type: 'sine',     seq: [[300, 0], [200, 0.06]],  dur: 0.12, gain: 0.8 },
  success: { type: 'triangle', seq: [[523, 0], [659, 0.08], [784, 0.16]], dur: 0.26, gain: 0.9 },
  error:   { type: 'sawtooth', seq: [[300, 0], [180, 0.1]],   dur: 0.20, gain: 0.6 },
};
const MASTER = 0.4;       // 낮게 고정 (볼륨 슬라이더 없음)
const THROTTLE_MS = 120;  // 같은 소리 최소 간격

function createSounds({ enabled = true, now = () => performance.now() } = {}) {
  let on = !!enabled;
  const last = {};       // name → 마지막 재생 시각(ms)
  let ctx = null;        // AudioContext (lazy)
  let bgm = null;

  function ensureCtx() {
    if (!ctx) {
      const AC = window.AudioContext || window.webkitAudioContext;
      if (!AC) return null;
      ctx = new AC();
    }
    if (ctx.state === 'suspended') ctx.resume();
    return ctx;
  }

  function _shouldPlay(name) {
    if (!on || !RECIPES[name]) return false;
    const t = now();
    const prev = last[name];
    if (prev != null && t - prev < THROTTLE_MS) return false;
    last[name] = t;
    return true;
  }

  function play(name) {
    if (!_shouldPlay(name)) return;
    const r = RECIPES[name];
    try {
      if (!ensureCtx()) return;
      // Chromium은 유저 제스처 뒤에도 AudioContext를 suspended로 두는 경우가 있다.
      // resume 안 하면 currentTime이 안 흘러 envelope가 안 울려 무음이 된다.
      // play()는 클릭/드래그 등 유저 제스처 핸들러에서 호출되므로 즉시 resume + 스케줄이 표준.
      const t0 = ctx.currentTime;
      const osc = ctx.createOscillator();
      const g = ctx.createGain();
      osc.type = r.type;
      // seq: [freq, 상대시각(s)] — 주파수 스텝
      for (const [freq, at] of r.seq) osc.frequency.setValueAtTime(freq, t0 + at);
      // 엔벨로프: 빠른 어택 후 dur 동안 페이드아웃
      const peak = MASTER * (r.gain != null ? r.gain : 1);
      g.gain.setValueAtTime(0.0001, t0);
      g.gain.exponentialRampToValueAtTime(peak, t0 + 0.008);
      g.gain.exponentialRampToValueAtTime(0.0001, t0 + r.dur);
      osc.connect(g).connect(ctx.destination);
      osc.start(t0);
      osc.stop(t0 + r.dur + 0.02);
    } catch { /* 펫이 멈추면 안 됨 — 오디오 실패는 무시 */ }
  }

  function scheduleBgmNote(master, freq, at, dur, type, gain = 0.06) {
    const c = ensureCtx();
    if (!c) return;
    const osc = c.createOscillator();
    const g = c.createGain();
    osc.type = type || 'sine';
    osc.frequency.setValueAtTime(freq, at);
    g.gain.setValueAtTime(0.0001, at);
    g.gain.exponentialRampToValueAtTime(gain, at + 0.025);
    g.gain.exponentialRampToValueAtTime(0.0001, at + dur);
    osc.connect(g).connect(master);
    osc.start(at);
    osc.stop(at + dur + 0.05);
  }

  function stopBgm() {
    if (!bgm) return;
    clearInterval(bgm.timer);
    try {
      const c = ensureCtx();
      if (c && bgm.master) {
        bgm.master.gain.cancelScheduledValues(c.currentTime);
        bgm.master.gain.setTargetAtTime(0.0001, c.currentTime, 0.18);
        setTimeout(() => { try { bgm.master.disconnect(); } catch { /* ignore */ } }, 450);
      }
    } catch { /* ignore */ }
    bgm = null;
  }

  function playBgm(preset = {}) {
    try {
      const c = ensureCtx();
      if (!c) return false;
      stopBgm();
      const bpm = Number(preset.bpm) || 82;
      const beat = 60 / bpm;
      const root = Number(preset.root) || 220;
      const scale = Array.isArray(preset.scale) && preset.scale.length ? preset.scale : [0, 3, 5, 7, 10];
      const wave = preset.wave || 'sine';
      const master = c.createGain();
      master.gain.setValueAtTime(0.0001, c.currentTime);
      master.gain.exponentialRampToValueAtTime(0.13, c.currentTime + 0.6);
      master.connect(c.destination);

      const melody = [0, 2, 4, 1, 3, 2, 0, 4];
      const bass = [0, 3, 2, 4];
      const scheduleLoop = () => {
        const t0 = c.currentTime + 0.08;
        for (let i = 0; i < 8; i++) {
          const semi = scale[melody[i] % scale.length];
          scheduleBgmNote(master, root * (2 ** (semi / 12)), t0 + i * beat, beat * 0.72, wave, 0.035);
        }
        for (let i = 0; i < 4; i++) {
          const semi = scale[bass[i] % scale.length];
          scheduleBgmNote(master, (root / 2) * (2 ** (semi / 12)), t0 + i * beat * 2, beat * 1.65, 'sine', 0.045);
        }
      };
      scheduleLoop();
      bgm = { master, timer: setInterval(scheduleLoop, beat * 7600) };
      return true;
    } catch {
      stopBgm();
      return false;
    }
  }

  function setEnabled(b) { on = !!b; }

  return { play, playBgm, stopBgm, setEnabled, _shouldPlay };
}

module.exports = { RECIPES, createSounds };
