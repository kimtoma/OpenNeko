#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCHEME="${SCHEME:-OpenNeko}"
CONFIGURATION="${CONFIGURATION:-Release}"
DERIVED_DATA="${DERIVED_DATA:-$ROOT_DIR/.derivedData}"
DIST_DIR="$ROOT_DIR/dist"
APP_NAME="OpenNeko.app"
CREATE_DMG="${CREATE_DMG:-1}"

cd "$ROOT_DIR"

if [[ "${NOTARIZE:-0}" == "1" && -z "${DEVELOPER_ID_APPLICATION:-}" ]]; then
  echo "NOTARIZE=1 requires DEVELOPER_ID_APPLICATION for a notarizable distribution build" >&2
  exit 1
fi

if [[ -n "${DEVELOPER_ID_APPLICATION:-}" ]]; then
  identity_output="$(security find-identity -p codesigning -v 2>&1 || true)"
  valid_developer_id_lines="$(grep 'Developer ID Application:' <<<"$identity_output" | grep -v 'CSSMERR' || true)"
  if ! grep -Fq "\"$DEVELOPER_ID_APPLICATION\"" <<<"$valid_developer_id_lines"; then
    echo "DEVELOPER_ID_APPLICATION was set but no matching valid identity was found" >&2
    exit 1
  fi
fi

if [[ "${NOTARIZE:-0}" == "1" ]]; then
  if [[ -z "${NOTARYTOOL_KEYCHAIN_PROFILE:-}" && ( -z "${APPLE_ID:-}" || -z "${APPLE_TEAM_ID:-}" || -z "${APPLE_APP_SPECIFIC_PASSWORD:-}" ) ]]; then
    echo "NOTARIZE=1 requires NOTARYTOOL_KEYCHAIN_PROFILE or APPLE_ID/APPLE_TEAM_ID/APPLE_APP_SPECIFIC_PASSWORD" >&2
    exit 1
  fi
fi

if command -v xcodegen >/dev/null 2>&1; then
  xcodegen generate
elif [[ ! -d "$ROOT_DIR/OpenNeko.xcodeproj" ]]; then
  echo "xcodegen is required to create OpenNeko.xcodeproj" >&2
  exit 1
fi

xcodebuild \
  -project "$ROOT_DIR/OpenNeko.xcodeproj" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -derivedDataPath "$DERIVED_DATA" \
  build

APP_PATH="$DERIVED_DATA/Build/Products/$CONFIGURATION/$APP_NAME"
if [[ ! -d "$APP_PATH" ]]; then
  echo "Built app not found: $APP_PATH" >&2
  exit 1
fi

rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"

ZIP_PATH="$DIST_DIR/openNeko-macOS-$CONFIGURATION.zip"
DMG_PATH="$DIST_DIR/openNeko-macOS-$CONFIGURATION.dmg"

if [[ -n "${DEVELOPER_ID_APPLICATION:-}" ]]; then
  /usr/bin/codesign \
    --force \
    --options runtime \
    --timestamp \
    --sign "$DEVELOPER_ID_APPLICATION" \
    "$APP_PATH"
fi

COPYFILE_DISABLE=1 /usr/bin/ditto \
  -c -k --keepParent --norsrc --noextattr \
  "$APP_PATH" \
  "$ZIP_PATH"

if [[ "${NOTARIZE:-0}" == "1" ]]; then
  if [[ -n "${NOTARYTOOL_KEYCHAIN_PROFILE:-}" ]]; then
    xcrun notarytool submit "$ZIP_PATH" \
      --keychain-profile "$NOTARYTOOL_KEYCHAIN_PROFILE" \
      --wait
  else
    xcrun notarytool submit "$ZIP_PATH" \
      --apple-id "$APPLE_ID" \
      --team-id "$APPLE_TEAM_ID" \
      --password "$APPLE_APP_SPECIFIC_PASSWORD" \
      --wait
  fi

  xcrun stapler staple "$APP_PATH"
  COPYFILE_DISABLE=1 /usr/bin/ditto \
    -c -k --keepParent --norsrc --noextattr \
    "$APP_PATH" \
    "$ZIP_PATH"
fi

if [[ "$CREATE_DMG" == "1" ]]; then
  DMG_STAGE="$(mktemp -d)"
  trap 'rm -rf "$DMG_STAGE"' EXIT
  COPYFILE_DISABLE=1 /usr/bin/ditto \
    --norsrc --noextattr \
    "$APP_PATH" \
    "$DMG_STAGE/$APP_NAME"
  /bin/ln -s /Applications "$DMG_STAGE/Applications"
  /bin/rm -f "$DMG_PATH"
  /usr/sbin/diskutil image create from \
    --format UDZO \
    --volumeName "openNeko" \
    "$DMG_STAGE" \
    "$DMG_PATH"
fi

echo "$ZIP_PATH"
if [[ "$CREATE_DMG" == "1" ]]; then
  echo "$DMG_PATH"
fi
