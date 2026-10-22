#!/usr/bin/env bash
set -euo pipefail

# Run the real CatScene without launching the app. For before/after timing:
#   scripts/verify-cat-scene-cache.sh --benchmark-only --scene-source /path/to/CatScene.swift
#   scripts/verify-cat-scene-cache.sh --verify-only --verify-actions \
#     --sprites-root /path/to/openNeko.app/Contents/Resources/sprites \
#     --expected-source-pixels 1024 --capture-pixels 1024 --sprite-output /tmp/openneko-captures
# Add --frame-cycle-states walk,typing,dragging,error,coding and
# --frame-cycle-output /tmp/openneko-motion-frames to check every running
# texture against its source and capture actual velocity-selected drag poses.
# Capture source size is required explicitly or through root render-info.json;
# the output defaults to a 256px (2x) capture of the unchanged 128pt scene.
# Use the same developer directory, sprite assets, and machine for both runs.
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCENE_SOURCE="$ROOT_DIR/App/CatScene.swift"
SPRITES_ROOT="$ROOT_DIR/App/Resources/sprites"
RUN_ARGUMENTS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --scene-source)
      SCENE_SOURCE="${2:?--scene-source requires a Swift file}"
      shift 2
      ;;
    --sprites-root)
      SPRITES_ROOT="${2:?--sprites-root requires a sprites directory}"
      shift 2
      ;;
    *)
      RUN_ARGUMENTS+=("$1")
      shift
      ;;
  esac
done

WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/openneko-cat-scene-cache.XXXXXX")"
trap 'rm -rf "$WORK_DIR"' EXIT
TARGET="$(uname -m)-apple-macosx14.0"
COMPILER_ARGUMENTS=(-O -target "$TARGET" -module-cache-path "$WORK_DIR/ModuleCache")
xcrun swiftc --version

# Keep this independent of the app's Xcode signing and the SwiftPM build cache.
# These are CatScene's real core dependencies, compiled with the same toolchain.
xcrun swiftc "${COMPILER_ARGUMENTS[@]}" \
  -emit-library -emit-module -module-name OpenNekoKit \
  -emit-module-path "$WORK_DIR/OpenNekoKit.swiftmodule" \
  "$ROOT_DIR/Sources/OpenNekoKit/State/CatState.swift" \
  "$ROOT_DIR/Sources/OpenNekoKit/State/CatAnimationTiming.swift" \
  "$ROOT_DIR/Sources/OpenNekoKit/State/CatDragGeometry.swift" \
  "$ROOT_DIR/Sources/OpenNekoKit/State/CatLayoutMetrics.swift" \
  "$ROOT_DIR/Sources/OpenNekoKit/State/ScreenPetEncounter.swift" \
  "$ROOT_DIR/Sources/OpenNekoKit/Skin/Skin.swift" \
  "$ROOT_DIR/Sources/OpenNekoKit/Skin/SkinManager.swift" \
  "$ROOT_DIR/Sources/OpenNekoKit/Skin/SpriteManifest.swift" \
  -o "$WORK_DIR/libOpenNekoKit.dylib"

xcrun swiftc "${COMPILER_ARGUMENTS[@]}" \
  -I "$WORK_DIR" -L "$WORK_DIR" -lOpenNekoKit \
  -Xlinker -rpath -Xlinker "$WORK_DIR" \
  "$SCENE_SOURCE" "$ROOT_DIR/scripts/verify-cat-scene-cache.swift" \
  -o "$WORK_DIR/verify-cat-scene-cache"

"$WORK_DIR/verify-cat-scene-cache" \
  --sprites-root "$SPRITES_ROOT" ${RUN_ARGUMENTS[@]+"${RUN_ARGUMENTS[@]}"}
