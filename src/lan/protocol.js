// LAN 피어 간 메시지 — 순수 검증/직렬화. 네트워크/소켓은 link.js 담당.
const TYPES = ['hello', 'presence', 'wave', 'greeting', 'bye'];
const PRESENCE = ['idle', 'coding', 'typing', 'away'];
const MAX_RAW = 2048;
const str = (v, max) => (typeof v === 'string' ? v.slice(0, max) : null);

// 내부 14상태 → coarse 4값. 공유 안전(세부 상태 노출 안 함).
function coarsePresence(anim) {
  if (anim === 'typing') return 'typing';
  if (anim === 'coding' || anim === 'thinking') return 'coding';
  if (anim === 'nap' || anim === 'yawn') return 'away';
  return 'idle';
}

function validate(m) {
  if (!m || typeof m !== 'object' || !TYPES.includes(m.t)) return null;
  if (m.t === 'hello') {
    const id = str(m.id, 64), name = str(m.name, 64), skin = str(m.skin, 32);
    if (!id) return null;
    return { t: 'hello', id, name: name || '', skin: skin || 'white' };
  }
  if (m.t === 'presence') {
    return PRESENCE.includes(m.state) ? { t: 'presence', state: m.state } : null;
  }
  if (m.t === 'wave') return { t: 'wave' };
  if (m.t === 'greeting') {
    return Number.isInteger(m.key) && m.key >= 0 && m.key < 100 ? { t: 'greeting', key: m.key } : null;
  }
  if (m.t === 'bye') return { t: 'bye' };
  return null;
}

function encode(msg) {
  const v = validate(msg);
  if (!v) throw new Error('invalid outgoing message: ' + JSON.stringify(msg));
  return JSON.stringify(v) + '\n';
}

function parse(raw) {
  if (typeof raw !== 'string' || raw.length > MAX_RAW) return null;
  let m;
  try { m = JSON.parse(raw); } catch { return null; }
  return validate(m);
}

module.exports = { TYPES, PRESENCE, MAX_RAW, encode, parse, coarsePresence };
