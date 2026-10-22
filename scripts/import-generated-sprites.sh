#!/usr/bin/env bash
# Import image_gen sources into staging; never generate/recolor/install artwork.
set -euo pipefail

if [[ $# -lt 2 ]]; then
  printf 'Usage: bash scripts/import-generated-sprites.sh SOURCE_DIR_OR_MANIFEST.json STAGING_DIR [highres1024|highres|pixel64] [--background auto|alpha|neutral-edge|chroma-magenta|chroma-magenta-pixel] [--punch-facing left|right]\n' >&2
  exit 2
fi

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source_input=$1
stage_input=$2
shift 2
mode=
if [[ $# -gt 0 && "$1" != --* ]]; then
  mode=$1
  shift
fi
background_args=()
punch_facing_args=()
while [[ $# -gt 0 ]]; do
  if [[ $# -lt 2 ]]; then
    printf 'Expected a value after %s\n' "$1" >&2
    exit 2
  fi
  case "$1" in
    --background)
      case "$2" in
        auto|alpha|neutral-edge|chroma-magenta|chroma-magenta-pixel) background_args=(--background "$2") ;;
        *) printf 'Background must be auto, alpha, neutral-edge, chroma-magenta, or chroma-magenta-pixel\n' >&2; exit 2 ;;
      esac ;;
    --punch-facing)
      case "$2" in
        left|right) punch_facing_args=(--punch-facing "$2") ;;
        *) printf 'Punch facing must be left or right\n' >&2; exit 2 ;;
      esac ;;
    *) printf 'Unknown option: %s\n' "$1" >&2; exit 2 ;;
  esac
  shift 2
done
mkdir -p "$stage_input"
stage_root=$(cd "$stage_input" && pwd)
source_manifest=
source_root=
if [[ -f "$source_input" ]]; then
  source_manifest="$(cd "$(dirname "$source_input")" && pwd)/$(basename "$source_input")"
  mode=${mode:-highres1024}
else
  source_root=$(cd "$source_input" && pwd)
  mode=${mode:-highres}
fi
case "$mode" in
  highres1024) jump_span=800; effect_span=832; neutral_floor=160; neutral_spread=36 ;;
  highres) jump_span=200; effect_span=208; neutral_floor=160; neutral_spread=36 ;;
  pixel64) jump_span=50; effect_span=52; neutral_floor=220; neutral_spread=18 ;;
  *) printf 'Mode must be highres1024, highres, or pixel64\n' >&2; exit 2 ;;
esac

if [[ -z "$source_manifest" ]]; then
  for skin in default black calico orange pink; do
    for sheet in a b c d; do
      if [[ ! -f "$source_root/$skin-$sheet.png" ]]; then
        printf 'Missing generated sheet: %s\n' "$source_root/$skin-$sheet.png" >&2
        exit 1
      fi
    done
  done
  if [[ ! -f "$source_root/effects-punch.png" ]]; then
    printf 'Missing generated effect sheet: %s\n' "$source_root/effects-punch.png" >&2
    exit 1
  fi
fi

tool_dir=$(mktemp -d "${TMPDIR:-/tmp}/openneko-sprite-production.XXXXXX")
trap 'rm -rf "$tool_dir"' EXIT
swiftc -O -module-cache-path /tmp/openneko-sprite-module-cache \
  "$repo_root/scripts/sprite-production.swift" -o "$tool_dir/sprite-production"
"$tool_dir/sprite-production" self-test

if [[ -n "$source_manifest" ]]; then
  "$tool_dir/sprite-production" import-manifest --mode "$mode" \
    --source-manifest "$source_manifest" --output-dir "$stage_root" ${background_args[@]+"${background_args[@]}"}
else
  for skin in default black calico orange pink; do
    for sheet in a b c d; do
      case "$sheet" in
        a) states=idle,hover,click,coding ;;
        b) states=typing,thinking,lunch,yawn ;;
        c) states=nap,success,error,dragging ;;
        d) states=walk,jump ;;
      esac
      "$tool_dir/sprite-production" import \
        --mode "$mode" \
        --sheet "$source_root/$skin-$sheet.png" \
        --output-dir "$stage_root/$skin" \
        --states "$states" --columns 4 --rows 4 \
        --state-limits "jump:$jump_span" --keep-main-body-states nap,success \
        --neutral-floor "$neutral_floor" --neutral-spread "$neutral_spread" \
        ${background_args[@]+"${background_args[@]}"} \
        --report "$stage_root/$skin-$sheet-import.json" \
        --preview "$stage_root/$skin-$sheet-preview.png"
    done
  done

  "$tool_dir/sprite-production" import \
    --mode "$mode" \
    --sheet "$source_root/effects-punch.png" \
    --output-dir "$stage_root/effects" --states nyang_punch \
    --columns 2 --rows 2 --single-state-grid true \
    --state-limits "nyang_punch:$effect_span" --keep-main-body-states nyang_punch \
    --neutral-floor "$neutral_floor" --neutral-spread "$neutral_spread" \
    ${background_args[@]+"${background_args[@]}"} \
    --report "$stage_root/effects-punch-import.json" \
    --preview "$stage_root/effects-punch-preview.png"
fi

"$tool_dir/sprite-production" metadata --mode "$mode" --sprites "$stage_root" \
  --manifest "$repo_root/App/Resources/sprites/manifest.json"
"$tool_dir/sprite-production" effect-metadata --mode "$mode" --sprites "$stage_root/effects" \
  ${punch_facing_args[@]+"${punch_facing_args[@]}"}
"$tool_dir/sprite-production" audit --mode "$mode" --sprites "$stage_root" \
  --manifest "$repo_root/App/Resources/sprites/manifest.json" \
  --source-reports "$stage_root" \
  --report "$stage_root/staged-bundle-audit.json"
"$tool_dir/sprite-production" background-preview --mode "$mode" --sprites "$stage_root" \
  --output-dir "$stage_root/background-previews"
"$tool_dir/sprite-production" background-preview --mode "$mode" --sprites "$stage_root" --skins effects \
  --samples nyang_punch_0,nyang_punch_1,nyang_punch_2,nyang_punch_3 \
  --output-dir "$stage_root/effects-background-previews"
