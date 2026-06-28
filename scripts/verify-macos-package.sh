#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIGURATION="${CONFIGURATION:-Release}"
APP_PATH="${APP_PATH:-$ROOT_DIR/.derivedData/Build/Products/$CONFIGURATION/OpenNeko.app}"
ZIP_PATH="${ZIP_PATH:-$ROOT_DIR/dist/openNeko-macOS-$CONFIGURATION.zip}"
DMG_PATH="${DMG_PATH:-$ROOT_DIR/dist/openNeko-macOS-$CONFIGURATION.dmg}"
MODE="${1:-local}"

case "$MODE" in
  local|distribution|notarized)
    ;;
  *)
    echo "usage: $0 [local|distribution|notarized]" >&2
    exit 2
    ;;
esac

fail() {
  echo "error: $*" >&2
  exit 1
}

note() {
  echo "ok: $*"
}

warn() {
  echo "note: $*"
}

plist_value() {
  /usr/libexec/PlistBuddy -c "Print $1" "$APP_PATH/Contents/Info.plist"
}

[[ -d "$APP_PATH" ]] || fail "app bundle not found: $APP_PATH"
[[ -f "$APP_PATH/Contents/MacOS/OpenNeko" ]] || fail "app executable missing"
[[ -f "$APP_PATH/Contents/Info.plist" ]] || fail "Info.plist missing"

bundle_id="$(plist_value CFBundleIdentifier)"
version="$(plist_value CFBundleShortVersionString)"
build="$(plist_value CFBundleVersion)"
minimum_system="$(plist_value LSMinimumSystemVersion)"

[[ "$bundle_id" == "com.kimtoma.openneko" ]] || fail "unexpected bundle id: $bundle_id"
[[ -n "$version" ]] || fail "missing marketing version"
[[ -n "$build" ]] || fail "missing build version"
[[ "$minimum_system" == "14.0" ]] || fail "unexpected minimum system version: $minimum_system"
note "bundle metadata $bundle_id $version ($build), macOS $minimum_system+"

/usr/bin/codesign --verify --deep --strict "$APP_PATH"
codesign_details="$(/usr/bin/codesign -dv --verbose=4 "$APP_PATH" 2>&1)"
note "codesign strict verification passed"

if ! grep -Eq "flags=.*runtime" <<<"$codesign_details"; then
  fail "hardened runtime flag is missing"
fi
note "hardened runtime flag present"

if [[ "$MODE" == "distribution" || "$MODE" == "notarized" ]]; then
  if grep -q "Signature=adhoc" <<<"$codesign_details"; then
    fail "distribution mode requires a Developer ID signature, found ad-hoc"
  fi
  if ! grep -q "^Authority=Developer ID Application:" <<<"$codesign_details"; then
    fail "Developer ID Application authority missing"
  fi
  note "Developer ID signature present"

  /usr/sbin/spctl --assess --type execute --verbose=4 "$APP_PATH"
  note "Gatekeeper execute assessment passed"
else
  if grep -q "Signature=adhoc" <<<"$codesign_details"; then
    warn "local ad-hoc signature; use distribution mode after Developer ID signing"
  fi
fi

sprite_count="$(find "$APP_PATH/Contents/Resources/sprites" -name '*.png' 2>/dev/null | wc -l | tr -d ' ')"
skill_count="$(find "$APP_PATH/Contents/Resources/skills/builtin" -name 'SKILL.md' 2>/dev/null | wc -l | tr -d ' ')"
[[ "$sprite_count" -gt 0 ]] || fail "sprite resources missing"
[[ "$skill_count" -gt 0 ]] || fail "bundled skills missing"
note "resources included: $sprite_count sprites, $skill_count bundled skills"

if [[ -f "$ZIP_PATH" ]]; then
  /usr/bin/unzip -t "$ZIP_PATH" >/dev/null
  if /usr/bin/unzip -Z1 "$ZIP_PATH" | /usr/bin/grep -Eq '(^|/)\._|^__MACOSX/'; then
    fail "zip contains AppleDouble metadata files"
  fi
  note "zip archive verified: $ZIP_PATH"
elif [[ "$MODE" == "distribution" || "$MODE" == "notarized" ]]; then
  fail "zip package not found: $ZIP_PATH"
else
  warn "zip package not found: $ZIP_PATH"
fi

if [[ -f "$DMG_PATH" ]]; then
  /usr/bin/hdiutil verify "$DMG_PATH" >/dev/null
  note "dmg checksum verified: $DMG_PATH"
else
  warn "dmg package not found: $DMG_PATH"
fi

if [[ "$MODE" == "notarized" ]]; then
  xcrun stapler validate "$APP_PATH"
  note "notarization ticket stapled"
fi
