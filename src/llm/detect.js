const { PRESETS } = require('./presets');

const OLLAMA_TIMEOUT_MS = 1500;

// 지금 바로 쓸 수 있는 백엔드를 발견한다(키 입력 없이 원클릭 활성화용).
// deps 주입(env/fetch)으로 단위 테스트 가능.
async function detectProviders({ env = {}, fetch }) {
  const out = [];

  // 1) 환경변수 키
  for (const p of PRESETS) {
    const key = p.envKey && env[p.envKey];
    if (key) out.push({ presetId: p.id, label: p.label, source: 'env', detail: p.envKey, ready: true });
  }

  // 2) 로컬 Ollama
  const ollama = PRESETS.find((p) => p.id === 'ollama');
  if (ollama && fetch) {
    try {
      const ctrl = new AbortController();
      const timer = setTimeout(() => ctrl.abort(), OLLAMA_TIMEOUT_MS);
      let res;
      try { res = await fetch(`${ollama.local}/api/tags`, { signal: ctrl.signal }); }
      finally { clearTimeout(timer); }
      if (res && res.ok) {
        const body = await res.json().catch(() => ({}));
        const models = Array.isArray(body.models) ? body.models.map((m) => m && m.name).filter(Boolean) : [];
        out.push({ presetId: 'ollama', label: ollama.label, source: 'local', detail: ollama.local, models, ready: true });
      }
    } catch { /* 꺼져 있음 — 무시 */ }
  }

  return out;
}

module.exports = { detectProviders };
