// SKILL.md 발견·파싱·조합 (순수 함수, 테스트 가능)
// model A: 지침을 LLM system 프롬프트로 주입. 스크립트 실행 없음.

const VALID_INPUT = ['clipboard', 'prompt', 'none'];
const MAX_BODY_BYTES = 16 * 1024; // 16KB 상한 (폭주 방지)

/**
 * SKILL.md 마크다운을 파싱해 스킬 객체 반환.
 * @param {string} md - 마크다운 원문
 * @param {string} id - 폴더명(스킬 ID)
 * @param {string} source - 발견된 디렉토리 경로
 */
function parseSkill(md, id, source) {
  let name = id, description = '', input = 'prompt', body = String(md || '');
  const m = /^\s*---\n([\s\S]*?)\n---\n?([\s\S]*)$/.exec(body);
  if (m) {
    body = m[2];
    for (const line of m[1].split('\n')) {
      const kv = /^(\w[\w-]*)\s*:\s*(.*)$/.exec(line.trim());
      if (!kv) continue;
      const k = kv[1].toLowerCase();
      const v = kv[2].trim().replace(/^["']|["']$/g, '');
      if (k === 'name') name = v || id;
      else if (k === 'description') description = v;
      else if (k === 'input') input = VALID_INPUT.includes(v) ? v : 'prompt';
    }
  }
  // 본문 길이 상한
  const trimmedBody = body.trim().slice(0, MAX_BODY_BYTES);
  return { id, name, description, input, body: trimmedBody, source };
}

/**
 * 여러 디렉토리에서 SKILL.md를 발견해 파싱.
 * 같은 id 충돌 시 나중 dir 우선(사용자가 번들 덮어쓰기 가능).
 * @param {{ dirs: string[], readdir: Function, readFile: Function, exists: Function }} opts
 */
function discoverSkills({ dirs = [], readdir, readFile, exists }) {
  const byId = {};
  for (const dir of dirs) {
    let subs = [];
    try {
      if (!exists(dir)) continue;
      subs = readdir(dir);
    } catch { continue; }
    for (const sub of subs) {
      const file = `${dir}/${sub}/SKILL.md`;
      let md;
      try {
        if (!exists(file)) continue;
        md = readFile(file);
      } catch { continue; }
      byId[sub] = parseSkill(md, sub, dir); // 나중 dir이 같은 id를 덮어씀
    }
  }
  return Object.values(byId);
}

/**
 * 스킬 시스템 프롬프트 생성: 스킬 지침 + 페르소나 말투 결합.
 * @param {{ body: string }} skill
 * @param {string} personaText
 */
function buildSkillSystem(skill, personaText) {
  const body = (skill.body || '').trim();
  const persona = (personaText || '').trim();
  if (body && persona) return `${body}\n\n${persona}`;
  return body || persona;
}

/**
 * disabled 스킬을 제외한 활성 스킬 목록 반환.
 * @param {Array} all - 전체 스킬 배열
 * @param {string[]} disabledIds - 비활성 스킬 ID 배열
 */
function enabledSkills(all, disabledIds = []) {
  const dis = new Set(disabledIds);
  return all.filter((s) => !dis.has(s.id));
}

module.exports = { parseSkill, discoverSkills, buildSkillSystem, enabledSkills, VALID_INPUT };
