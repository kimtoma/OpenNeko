// git 기반 셀프 업데이트 — 순수 판단 로직 (네트워크/실행은 main.js에서 주입).
// 배포가 git clone(install.sh/ps1)이라 origin 대비 뒤처짐을 보고 알림 → 선택 시 pull+install+build+재시작.

// `git rev-list --count HEAD..origin/<branch>` 출력 → 뒤처진 커밋 수
function parseBehind(revListCount) {
  const n = parseInt(String(revListCount).trim(), 10);
  return Number.isFinite(n) && n > 0 ? n : 0;
}

// `git status --porcelain --untracked-files=no` 출력 → 추적 파일 로컬 변경(더티) 여부.
// (호출부에서 untracked 제외 — untracked는 ff-pull을 막지 않으므로 더티로 치지 않는다.)
function isDirty(statusPorcelain) {
  return String(statusPorcelain || '').trim().length > 0;
}

// 업데이트 가능 여부 판단. git 설치가 아니거나 더티면 자동 적용 불가.
function updateDecision({ isGit, behind, dirty }) {
  if (!isGit) return { available: false, reason: 'not-git', behind: 0 };
  if (dirty) return { available: false, reason: 'dirty', behind: behind || 0 };
  if (behind > 0) return { available: true, reason: 'behind', behind };
  return { available: false, reason: 'up-to-date', behind: 0 };
}

module.exports = { parseBehind, isDirty, updateDecision };
