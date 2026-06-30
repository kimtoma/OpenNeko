#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCHEME="${SCHEME:-OpenNeko}"
CONFIGURATION="${CONFIGURATION:-Release}"
DERIVED_DATA="${DERIVED_DATA:-$ROOT_DIR/.derivedData}"
DIST_DIR="$ROOT_DIR/dist"
APP_NAME="OpenNeko.app"
CREATE_DMG="${CREATE_DMG:-1}"
VOLUME_NAME="OpenNeko installer"
DMG_WINDOW_WIDTH=880
DMG_WINDOW_HEIGHT=560
DMG_APP_ICON_X=248
DMG_APP_ICON_Y=312
DMG_APPLICATIONS_ICON_X=632
DMG_APPLICATIONS_ICON_Y=312
DMG_ICON_SIZE=128
APP_ICON_CAT_ART="$ROOT_DIR/docs/assets/sprites/black/idle_0.png"

generate_app_icon() {
  /usr/bin/swift \
    "$ROOT_DIR/scripts/generate-app-icon.swift" \
    "$APP_ICON_CAT_ART" \
    "$ROOT_DIR/App/Resources/Assets.xcassets/AppIcon.appiconset"
}

create_volume_icon() {
  local output_path="$1"
  local iconset_dir="$DIST_DIR/openneko-volume.iconset"
  /bin/rm -rf "$iconset_dir"
  # The mounted volume is a white macOS-style disk cartridge with the OpenNeko
  # bar-icon cat engraved into its face.
  /usr/bin/swift \
    "$ROOT_DIR/scripts/generate-volume-icon.swift" \
    "$APP_ICON_CAT_ART" \
    "$iconset_dir"
  /usr/bin/iconutil -c icns -o "$output_path" "$iconset_dir"
  /bin/rm -rf "$iconset_dir"
}

write_dmg_ds_store() {
  local mount_dir="$1"
  local background_name="$2"

  /usr/bin/python3 "$ROOT_DIR/scripts/generate-dmg-ds-store.py" \
    --volume "$mount_dir" \
    --background "$background_name" \
    --window-width "$DMG_WINDOW_WIDTH" \
    --window-height "$DMG_WINDOW_HEIGHT" \
    --icon-size "$DMG_ICON_SIZE" \
    --app-name "$APP_NAME" \
    --app-position "$DMG_APP_ICON_X,$DMG_APP_ICON_Y" \
    --applications-position "$DMG_APPLICATIONS_ICON_X,$DMG_APPLICATIONS_ICON_Y"
}

cd "$ROOT_DIR"

generate_app_icon

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

ZIP_PATH="$DIST_DIR/OpenNeko-macOS-$CONFIGURATION.zip"
DMG_PATH="$DIST_DIR/OpenNeko-macOS-$CONFIGURATION.dmg"

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
  DMG_MOUNT=""
  DMG_RW_PATH="$DIST_DIR/OpenNeko-macOS-$CONFIGURATION.rw.dmg"
  DMG_DEVICE=""

  cleanup_dmg() {
    if [[ -n "$DMG_DEVICE" ]]; then
      /usr/bin/hdiutil detach "$DMG_DEVICE" -quiet || true
    fi
    /bin/rm -rf "$DMG_STAGE" "$DMG_RW_PATH"
  }
  trap cleanup_dmg EXIT

  COPYFILE_DISABLE=1 /usr/bin/ditto \
    --norsrc --noextattr \
    "$APP_PATH" \
    "$DMG_STAGE/$APP_NAME"
  /bin/ln -s /Applications "$DMG_STAGE/Applications"
  /bin/mkdir -p "$DMG_STAGE/.background"
  DMG_BACKGROUND_NAME="openneko-dmg-background.png"
  /usr/bin/swift "$ROOT_DIR/scripts/generate-dmg-background.swift" "$DMG_STAGE/.background/$DMG_BACKGROUND_NAME"
  create_volume_icon "$DMG_STAGE/.VolumeIcon.icns"
  /bin/chmod -R u+rw,go+r "$DMG_STAGE"

  /bin/rm -f "$DMG_PATH"
  /bin/rm -f "$DMG_RW_PATH"
  /usr/bin/hdiutil create \
    -volname "$VOLUME_NAME" \
    -srcfolder "$DMG_STAGE" \
    -format UDRW \
    -fs HFS+ \
    -ov \
    "$DMG_RW_PATH" >/dev/null

  /usr/bin/hdiutil resize -size 128m "$DMG_RW_PATH" >/dev/null
  attach_output="$(/usr/bin/hdiutil attach "$DMG_RW_PATH" -readwrite -noverify -noautoopen)"
  DMG_DEVICE="$(/usr/bin/awk '/^\/dev\/disk/ {print $1; exit}' <<<"$attach_output")"
  DMG_MOUNT="$(/usr/bin/awk -F '\t' '/\/Volumes\// {print $NF; exit}' <<<"$attach_output")"
  if [[ -z "$DMG_DEVICE" ]]; then
    echo "Failed to mount writable DMG" >&2
    exit 1
  fi
  if [[ -z "$DMG_MOUNT" ]]; then
    echo "Failed to determine writable DMG mount path" >&2
    exit 1
  fi

  /usr/bin/SetFile -a V "$DMG_MOUNT/.background"
  /usr/bin/chflags hidden "$DMG_MOUNT/.background" "$DMG_MOUNT/.VolumeIcon.icns"
  /usr/bin/SetFile -a C "$DMG_MOUNT"
  write_dmg_ds_store "$DMG_MOUNT" "$DMG_BACKGROUND_NAME"
  /bin/rm -rf "$DMG_MOUNT/.fseventsd" "$DMG_MOUNT/.Trashes"
  /bin/sync
  /usr/bin/hdiutil detach "$DMG_DEVICE" -quiet
  DMG_DEVICE=""

  /usr/bin/hdiutil convert \
    "$DMG_RW_PATH" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -o "$DMG_PATH" \
    -ov >/dev/null
fi

echo "$ZIP_PATH"
if [[ "$CREATE_DMG" == "1" ]]; then
  echo "$DMG_PATH"
fi
