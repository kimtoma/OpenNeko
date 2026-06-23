// 프로필 + 오늘 날짜를 시스템 프롬프트에 덧붙일 문자열 생성. 순수 함수, 테스트 가능.
const WD = ['일', '월', '화', '수', '목', '금', '토'];
function pad(n) { return String(n).padStart(2, '0'); }

/**
 * buildProfileContext(profile, now) → 시스템 프롬프트에 덧붙일 문자열
 * - 항상: "오늘 날짜: YYYY-MM-DD (요일)"
 * - birthDate 있으면: "사용자 생년월일: ... (음력?), 태어난 시각: ..."
 * - name 있으면: "사용자 이름: ..."
 */
function buildProfileContext(profile, now) {
  if (!profile || typeof profile !== 'object') profile = {};
  if (!now) now = new Date();
  const d = `${now.getFullYear()}-${pad(now.getMonth() + 1)}-${pad(now.getDate())}`;
  const lines = [`오늘 날짜: ${d} (${WD[now.getDay()]}요일)`];
  if (profile.birthDate) {
    let s = `사용자 생년월일: ${profile.birthDate}${profile.calendar === 'lunar' ? ' (음력)' : ''}`;
    if (profile.birthTime) s += `, 태어난 시각: ${profile.birthTime}`;
    lines.push(s);
  }
  if (profile.name) lines.push(`사용자 이름: ${profile.name}`);
  return lines.join('\n');
}

module.exports = { buildProfileContext };
