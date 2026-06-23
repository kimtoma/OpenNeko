const { PRESETS } = require('./presets');

const CLI_TIMEOUT_MS = 2000;
const LOCAL_TIMEOUT_MS = 1200;

async function isCodexLoggedIn(execFile, bin) {
  if (!execFile) return true;
  try {
    const res = await execFile(bin, ['login', 'status'], { timeout: CLI_TIMEOUT_MS });
    return /Logged in using ChatGPT/i.test(String((res && (res.stdout || res.stderr)) || ''));
  } catch { return false; }
}

async function fetchJSON(fetchImpl, url, timeoutMs = LOCAL_TIMEOUT_MS) {
  if (!fetchImpl) return null;
  const ctrl = new AbortController();
  const timer = setTimeout(() => ctrl.abort(), timeoutMs);
  try {
    const res = await fetchImpl(url, { signal: ctrl.signal });
    if (!res || !res.ok) return null;
    return await res.json();
  } catch {
    return null;
  } finally {
    clearTimeout(timer);
  }
}

async function detectOllama(fetchImpl) {
  const data = await fetchJSON(fetchImpl, 'http://127.0.0.1:11434/api/tags');
  if (!data || !Array.isArray(data.models)) return null;
  const models = data.models
    .map((m) => m && (m.name || m.model))
    .filter(Boolean);
  return { models };
}

// 지금 바로 쓸 수 있는 백엔드를 발견한다(키 입력 없이 원클릭 활성화용).
// deps 주입(env/which/execFile/fetch)으로 단위 테스트 가능.
async function detectProviders({ env = {}, which, execFile, fetch } = {}) {
  const out = [];

  // 1) 환경변수 키
  for (const p of PRESETS) {
    const keyName = (p.envKey && env[p.envKey]) ? p.envKey
      : ((p.envKeyAlt && env[p.envKeyAlt]) ? p.envKeyAlt : '');
    if (keyName) out.push({ presetId: p.id, label: p.label, source: 'env', detail: keyName, ready: true });
  }

  // 2) OAuth/CLI 백엔드
  for (const p of PRESETS) {
    if (!p.cliBin || !which || !which(p.cliBin)) continue;
    const ready = p.id === 'chatgpt-oauth' ? await isCodexLoggedIn(execFile, p.cliBin) : true;
    if (ready) out.push({ presetId: p.id, label: p.label, source: 'oauth', detail: p.cliBin, ready: true });
  }

  // 3) 로컬 모델 서버
  const ollama = await detectOllama(fetch);
  if (ollama) {
    out.push({
      presetId: 'ollama',
      label: 'Ollama',
      source: 'local',
      detail: '127.0.0.1:11434',
      ready: true,
      models: ollama.models,
      model: ollama.models[0] || '',
    });
  }

  return out;
}

module.exports = { detectProviders, detectOllama };
