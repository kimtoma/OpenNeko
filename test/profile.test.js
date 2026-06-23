const { test } = require('node:test');
const assert = require('node:assert');
const { buildProfileContext } = require('../src/profile');

// 결정적 기준 날짜: 2026-06-14 일요일
const NOW = new Date('2026-06-14T09:00:00+09:00');

test('빈 프로필 → 날짜 줄만 (생년월일·이름 줄 없음)', () => {
  const result = buildProfileContext({}, NOW);
  assert.match(result, /오늘 날짜: 2026-06-14 \(일요일\)/);
  assert.ok(!result.includes('생년월일'));
  assert.ok(!result.includes('이름'));
});

test('undefined 프로필 → 날짜 줄만', () => {
  const result = buildProfileContext(undefined, NOW);
  assert.match(result, /오늘 날짜: 2026-06-14/);
  assert.ok(!result.includes('생년월일'));
});

test('birthDate 양력 → "사용자 생년월일" 줄, 음력 표시 없음', () => {
  const result = buildProfileContext({ birthDate: '1990-03-15', calendar: 'solar' }, NOW);
  assert.match(result, /사용자 생년월일: 1990-03-15$/m);
  assert.ok(!result.includes('음력'));
});

test('birthDate + calendar:lunar → "(음력)" 표시', () => {
  const result = buildProfileContext({ birthDate: '1990-03-15', calendar: 'lunar' }, NOW);
  assert.match(result, /사용자 생년월일: 1990-03-15 \(음력\)/);
});

test('birthDate + birthTime → 시각 줄 포함', () => {
  const result = buildProfileContext({ birthDate: '1990-03-15', birthTime: '06:30' }, NOW);
  assert.match(result, /태어난 시각: 06:30/);
});

test('birthDate + calendar:lunar + birthTime 조합', () => {
  const result = buildProfileContext({ birthDate: '1990-03-15', calendar: 'lunar', birthTime: '06:30' }, NOW);
  assert.match(result, /사용자 생년월일: 1990-03-15 \(음력\), 태어난 시각: 06:30/);
});

test('name 있으면 "사용자 이름" 줄 포함', () => {
  const result = buildProfileContext({ name: '김경수' }, NOW);
  assert.match(result, /사용자 이름: 김경수/);
});

test('birthDate 없으면 birthTime만 있어도 생년월일 줄 없음', () => {
  const result = buildProfileContext({ birthTime: '06:30' }, NOW);
  assert.ok(!result.includes('생년월일'));
  assert.ok(!result.includes('시각'));
});

test('now 주입으로 날짜 결정적 — 월요일 검증', () => {
  const monday = new Date('2026-06-15T00:00:00+09:00');
  const result = buildProfileContext({}, monday);
  assert.match(result, /2026-06-15 \(월요일\)/);
});
