#!/usr/bin/env bash
# 정식 배포용 서명 + 공증(notarize) dmg 빌드.
#
# 필요 조건:
#   1) 키체인에 "Developer ID Application: <이름> (<팀ID>)" 인증서
#      (유료 Apple Developer Program 가입 후 발급 — README의 ".dmg 패키징" 섹션 참고)
#   2) 아래 환경변수 (비밀이므로 커밋 금지, 터미널에서 직접 export):
#        APPLE_ID                     Apple 계정 이메일
#        APPLE_APP_SPECIFIC_PASSWORD  appleid.apple.com에서 만든 앱 전용 암호 (xxxx-xxxx-xxxx-xxxx)
#        APPLE_TEAM_ID                10자리 팀 ID (예: X4374KBARM)
#
# 사용:  bash scripts/release-dmg.sh
#   -> dist/openNeko-<version>-arm64.dmg (installable without unsigned-app warnings)
set -euo pipefail
cd "$(dirname "$0")/.."

: "${APPLE_ID:?APPLE_ID 환경변수가 필요하다 (Apple 계정 이메일)}"
: "${APPLE_APP_SPECIFIC_PASSWORD:?APPLE_APP_SPECIFIC_PASSWORD가 필요하다 (앱 전용 암호)}"
: "${APPLE_TEAM_ID:?APPLE_TEAM_ID가 필요하다 (10자리 팀 ID)}"

# Developer ID Application 인증서 존재 확인 (없으면 친절히 안내하고 중단)
if ! security find-identity -v -p codesigning | grep -q "Developer ID Application"; then
  echo "✗ 키체인에 'Developer ID Application' 인증서가 없다." >&2
  echo "  Apple Developer Program 가입 후 Xcode 또는 developer.apple.com에서 발급받아야 한다." >&2
  echo "  자세한 절차: README의 .dmg 패키징 섹션" >&2
  exit 1
fi

echo "▶ 렌더러 번들 빌드"
npm run build

echo "▶ 서명 + 공증 dmg 빌드 (공증은 Apple 서버 왕복으로 수 분 소요)"
# package.json의 mac.identity=null을 CLI로 덮어써 Developer ID Application 자동 선택.
# 비밀 자격증명은 env로만 전달(APPLE_ID/APPLE_APP_SPECIFIC_PASSWORD는 electron-builder가 자동 인식).
npx electron-builder --mac dmg \
  --config.mac.identity="Developer ID Application" \
  --config.mac.hardenedRuntime=true \
  --config.mac.entitlements=build/entitlements.mac.plist \
  --config.mac.entitlementsInherit=build/entitlements.mac.plist \
  --config.mac.notarize.teamId="$APPLE_TEAM_ID" \
  --config.mac.gatekeeperAssess=false

DMG=$(ls -t dist/*.dmg 2>/dev/null | head -1 || true)
echo
if [ -n "${DMG:-}" ]; then
  echo "✓ 완료: $DMG"
  echo "▶ 공증/스테이플 검증:"
  xcrun stapler validate "$DMG" 2>&1 || echo "  (스테이플 검증 실패 — 공증 상태 확인 필요)"
  spctl -a -vvv -t install "$DMG" 2>&1 | head -5 || true
else
  echo "✗ dmg 생성 실패" >&2; exit 1
fi
