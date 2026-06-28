#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODE="${1:-distribution}"

case "$MODE" in
  local|distribution|notarized)
    ;;
  *)
    echo "usage: $0 [local|distribution|notarized]" >&2
    exit 2
    ;;
esac

failures=0

ok() {
  echo "ok: $*"
}

warn() {
  echo "warn: $*"
}

fail() {
  echo "error: $*" >&2
  failures=$((failures + 1))
}

require_command() {
  if command -v "$1" >/dev/null 2>&1; then
    ok "$1 available"
  else
    fail "$1 is required"
  fi
}

require_xcrun_tool() {
  if xcrun --find "$1" >/dev/null 2>&1; then
    ok "xcrun $1 available"
  else
    fail "xcrun $1 is required"
  fi
}

require_command xcodebuild
require_command xcrun
require_command security
require_command ditto
require_command hdiutil

if command -v xcodegen >/dev/null 2>&1; then
  ok "xcodegen available"
elif [[ -d "$ROOT_DIR/OpenNeko.xcodeproj" ]]; then
  warn "xcodegen missing; existing OpenNeko.xcodeproj will be reused"
else
  fail "xcodegen is required because OpenNeko.xcodeproj is missing"
fi

identity_output="$(security find-identity -p codesigning -v 2>&1 || true)"
valid_developer_id_lines="$(grep 'Developer ID Application:' <<<"$identity_output" | grep -v 'CSSMERR' || true)"
developer_id_count="$(grep -c 'Developer ID Application:' <<<"$valid_developer_id_lines" || true)"

if [[ "$MODE" == "local" ]]; then
  ok "local ad-hoc packaging does not require Developer ID"
else
  if [[ -n "${DEVELOPER_ID_APPLICATION:-}" ]]; then
    if grep -Fq "\"$DEVELOPER_ID_APPLICATION\"" <<<"$valid_developer_id_lines"; then
      ok "configured Developer ID identity found"
    else
      fail "DEVELOPER_ID_APPLICATION was set but no matching valid identity was found"
    fi
  elif [[ "$developer_id_count" -gt 0 ]]; then
    ok "Developer ID Application identity available"
  else
    fail "no valid Developer ID Application identity found in keychain"
  fi
fi

if [[ "$MODE" == "notarized" ]]; then
  require_xcrun_tool notarytool
  require_xcrun_tool stapler
  if [[ -n "${NOTARYTOOL_KEYCHAIN_PROFILE:-}" ]]; then
    ok "notarytool keychain profile configured: $NOTARYTOOL_KEYCHAIN_PROFILE"
  elif [[ -n "${APPLE_ID:-}" && -n "${APPLE_TEAM_ID:-}" && -n "${APPLE_APP_SPECIFIC_PASSWORD:-}" ]]; then
    ok "Apple ID notarization environment variables configured"
  else
    fail "notarized mode requires NOTARYTOOL_KEYCHAIN_PROFILE or APPLE_ID/APPLE_TEAM_ID/APPLE_APP_SPECIFIC_PASSWORD"
  fi
fi

if [[ "$failures" -gt 0 ]]; then
  echo "release preflight failed with $failures issue(s)" >&2
  exit 1
fi

ok "release preflight passed for $MODE mode"
