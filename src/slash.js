// 슬래시 명령 파서/매처 — 순수 함수, 렌더러와 main 모두에서 사용
'use strict';

/**
 * 입력 줄을 파싱해 슬래시 명령으로 분리.
 * '/'로 시작하지 않으면 null 반환(앞 공백이 있으면 슬래시가 아님).
 * @param {string} line
 * @returns {{ cmd: string, args: string } | null}
 */
function parseSlash(line) {
  const s = String(line || '');
  if (s[0] !== '/') return null;
  const rest = s.slice(1);
  const i = rest.indexOf(' ');
  if (i < 0) return { cmd: rest.toLowerCase(), args: '' };
  return { cmd: rest.slice(0, i).toLowerCase(), args: rest.slice(i + 1).trim() };
}

/**
 * prefix로 시작하는 카탈로그 항목 필터 (이름 오름차순).
 * 빈 prefix면 전체 반환.
 * @param {string} prefix
 * @param {Array<{name: string}>} catalog
 * @returns {Array<{name: string}>}
 */
function matchCommands(prefix, catalog = []) {
  const p = String(prefix || '').toLowerCase();
  return catalog
    .filter((c) => c.name.toLowerCase().startsWith(p))
    .sort((a, b) => a.name.localeCompare(b.name));
}

module.exports = { parseSlash, matchCommands };
