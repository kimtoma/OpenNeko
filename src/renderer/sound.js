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
      if (!ctx) {
        const AC = window.AudioContext || window.webkitAudioContext;
        if (!AC) return;       // 미지원 → 조용히 무시
        ctx = new AC();
      }
      // Chromium은 유저 제스처 뒤에도 AudioContext를 suspended로 두는 경우가 있다.
      // resume 안 하면 currentTime이 안 흘러 envelope가 안 울려 무음이 된다.
      // play()는 클릭/드래그 등 유저 제스처 핸들러에서 호출되므로 즉시 resume + 스케줄이 표준.
      if (ctx.state === 'suspended') ctx.resume();
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

  function setEnabled(b) { on = !!b; }

  return { play, setEnabled, _shouldPlay };
}

module.exports = { RECIPES, createSounds };
