const { PERSONA, persona } = require('./persona');
const MAX_TURNS = 6;

// 대화 이력 → 단일 프롬프트 문자열. 일부 OpenAI-compatible 게이트웨이 진단과 테스트에서 사용한다.
function formatPrompt(history) {
  const turns = history.slice(-MAX_TURNS);
  const last = turns[turns.length - 1];
  if (turns.length <= 1) return last ? last.text : '';
  const prior = turns.slice(0, -1)
    .map((m) => `${m.role === 'user' ? '나' : '너'}: ${m.text}`).join('\n');
  return `이전 대화:\n${prior}\n\n지금 질문: ${last.text}`;
}

// API용: 대화 이력 → role/content 메시지 배열
function historyToMessages(history) {
  return history.slice(-MAX_TURNS).map((m) => ({ role: m.role, content: m.text }));
}

// 에러 메시지에 끼어든 키 비슷한 값 제거 — 일부 게이트웨이가 4xx 본문에
// Authorization 헤더나 키 조각을 그대로 되비추기 때문에, UI/로그로 새지 않게 마스킹.
function redactSecrets(s) {
  return String(s || '')
    .replace(/Bearer\s+\S+/gi, 'Bearer •••')
    .replace(/sk-[A-Za-z0-9_-]{6,}/g, 'sk-•••')
    .replace(/AIza[A-Za-z0-9_-]{6,}/g, 'AIza•••') // Google API 키
    .replace(/(['"]?(?:api[_-]?key|x-api-key|key)['"]?\s*[:=]\s*['"]?)[^'",\s}]+/gi, '$1•••');
}

// HTTP 상태코드 → 사유 코드가 달린 Error
function httpError(status, body) {
  let code = 'HTTP';
  if (status === 401 || status === 403) code = 'AUTH';
  else if (status === 404) code = 'NOTFOUND';
  const snippet = redactSecrets(body).slice(0, 200);
  return Object.assign(new Error(`HTTP ${status}${snippet ? ': ' + snippet : ''}`), { code });
}

// 타임아웃과 외부 취소(signal)를 구분하는 AbortController 래퍼.
// 타임아웃으로 끊긴 fetch/read는 AbortError를 던지는데, 그대로 두면 사용자 취소와
// 구분이 안 돼 main이 조용히 삼킨다(thinking 무한 + 이력 오염). rethrow가 타임아웃이면
// 호출부가 공통으로 처리할 수 있게 code:'ETIMEDOUT'로 변환한다.
function makeAbort(signal, timeoutMs) {
  const ctrl = new AbortController();
  let timedOut = false;
  const timer = setTimeout(() => { timedOut = true; ctrl.abort(); }, timeoutMs);
  const onAbort = () => ctrl.abort();
  if (signal) signal.addEventListener('abort', onAbort, { once: true });
  return {
    signal: ctrl.signal,
    clear() { clearTimeout(timer); if (signal) signal.removeEventListener('abort', onAbort); },
    rethrow(e) {
      this.clear();
      if (e && e.name === 'AbortError' && timedOut) {
        return Object.assign(new Error('응답 시간 초과'), { code: 'ETIMEDOUT' });
      }
      return e; // 사용자 취소(AbortError)는 그대로 — main이 새 메시지 취소로 처리
    },
  };
}

module.exports = { PERSONA, persona, MAX_TURNS, formatPrompt, historyToMessages, httpError, makeAbort, redactSecrets };
