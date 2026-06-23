const { test } = require('node:test');
const assert = require('node:assert');
const { parseSkill, discoverSkills, buildSkillSystem, enabledSkills } = require('../src/skills');

// --- parseSkill ---

test('parseSkill: frontmatter name/description/input 파싱', () => {
  const md = `---
name: 클립보드 요약
description: 복사한 텍스트를 요약
input: clipboard
---
복사한 내용을 요약해줘.`;
  const s = parseSkill(md, 'clipboard-summary', '/bundled');
  assert.equal(s.id, 'clipboard-summary');
  assert.equal(s.name, '클립보드 요약');
  assert.equal(s.description, '복사한 텍스트를 요약');
  assert.equal(s.input, 'clipboard');
  assert.equal(s.body.trim(), '복사한 내용을 요약해줘.');
  assert.equal(s.source, '/bundled');
});

test('parseSkill: input 기본값은 prompt', () => {
  const md = `---
name: 설명 스킬
---
어렵지 않게 설명해줘.`;
  const s = parseSkill(md, 'explain', '/bundled');
  assert.equal(s.input, 'prompt');
});

test('parseSkill: 잘못된 input은 prompt로 폴백', () => {
  const md = `---
input: invalid-value
---
본문`;
  const s = parseSkill(md, 'bad-input', '/bundled');
  assert.equal(s.input, 'prompt');
});

test('parseSkill: name 없으면 id 사용', () => {
  const md = `---
description: 설명만 있음
---
본문`;
  const s = parseSkill(md, 'my-skill', '/bundled');
  assert.equal(s.name, 'my-skill');
});

test('parseSkill: frontmatter 없으면 전체가 body, 기본값 적용', () => {
  const md = '그냥 본문이에요.';
  const s = parseSkill(md, 'plain', '/bundled');
  assert.equal(s.name, 'plain');
  assert.equal(s.input, 'prompt');
  assert.equal(s.body, '그냥 본문이에요.');
});

test('parseSkill: input none 허용', () => {
  const md = `---
name: 자동 실행
input: none
---
`;
  const s = parseSkill(md, 'auto', '/dir');
  assert.equal(s.input, 'none');
});

// --- discoverSkills ---

test('discoverSkills: 여러 dir 스캔, SKILL.md 있는 폴더만 파싱', () => {
  const fs = {
    exists: (p) => {
      if (p === '/bundled') return true;
      if (p === '/bundled/summary/SKILL.md') return true;
      if (p === '/bundled/nofile') return false; // no SKILL.md
      return false;
    },
    readdir: (d) => {
      if (d === '/bundled') return ['summary', 'nofile'];
      return [];
    },
    readFile: (f) => {
      if (f === '/bundled/summary/SKILL.md') return '---\nname: 요약\ninput: clipboard\n---\n요약해줘.';
      throw new Error('not found');
    },
  };
  const skills = discoverSkills({ dirs: ['/bundled'], ...fs });
  assert.equal(skills.length, 1);
  assert.equal(skills[0].id, 'summary');
  assert.equal(skills[0].name, '요약');
});

test('discoverSkills: 같은 id는 나중 dir 우선(사용자가 번들 덮어쓰기)', () => {
  const fs = {
    exists: (p) => ['/bundled', '/user', '/bundled/skill-a/SKILL.md', '/user/skill-a/SKILL.md'].includes(p),
    readdir: (d) => {
      if (d === '/bundled') return ['skill-a'];
      if (d === '/user') return ['skill-a'];
      return [];
    },
    readFile: (f) => {
      if (f === '/bundled/skill-a/SKILL.md') return '---\nname: 번들\n---\n번들 본문';
      if (f === '/user/skill-a/SKILL.md') return '---\nname: 사용자\n---\n사용자 본문';
      throw new Error('not found');
    },
  };
  const skills = discoverSkills({ dirs: ['/bundled', '/user'], ...fs });
  assert.equal(skills.length, 1);
  assert.equal(skills[0].name, '사용자'); // 나중 dir 우선
  assert.equal(skills[0].source, '/user');
});

test('discoverSkills: 없는 dir은 건너뜀', () => {
  const fs = {
    exists: (p) => p === '/real',
    readdir: (d) => {
      if (d === '/real') return [];
      throw new Error('ENOENT');
    },
    readFile: () => { throw new Error('not found'); },
  };
  const skills = discoverSkills({ dirs: ['/nonexistent', '/real'], ...fs });
  assert.equal(skills.length, 0);
});

// --- buildSkillSystem ---

test('buildSkillSystem: body + persona 결합', () => {
  const skill = { body: '이 스킬의 지침입니다.' };
  const result = buildSkillSystem(skill, '~냥 말투를 써줘');
  assert.ok(result.includes('이 스킬의 지침입니다.'));
  assert.ok(result.includes('~냥 말투를 써줘'));
});

test('buildSkillSystem: body가 빈 문자열이어도 persona는 포함됨', () => {
  const skill = { body: '' };
  const result = buildSkillSystem(skill, '페르소나');
  assert.ok(result.includes('페르소나'));
});

// --- enabledSkills ---

test('enabledSkills: disabled 제외', () => {
  const all = [
    { id: 'a', name: 'A' },
    { id: 'b', name: 'B' },
    { id: 'c', name: 'C' },
  ];
  const result = enabledSkills(all, ['b']);
  assert.deepEqual(result.map((s) => s.id), ['a', 'c']);
});

test('enabledSkills: disabledIds 비어있으면 전부 반환', () => {
  const all = [{ id: 'a' }, { id: 'b' }];
  assert.equal(enabledSkills(all, []).length, 2);
  assert.equal(enabledSkills(all).length, 2);
});

test('enabledSkills: 전부 disabled이면 빈 배열', () => {
  const all = [{ id: 'x' }, { id: 'y' }];
  assert.equal(enabledSkills(all, ['x', 'y']).length, 0);
});
