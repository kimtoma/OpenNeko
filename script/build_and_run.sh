#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCHEME="${SCHEME:-OpenNeko}"
CONFIGURATION="${CONFIGURATION:-Debug}"
DERIVED_DATA="${DERIVED_DATA:-$ROOT_DIR/.derivedData}"
APP_NAME="OpenNeko"
APP_BUNDLE="$DERIVED_DATA/Build/Products/$CONFIGURATION/$APP_NAME.app"
APP_BINARY="$APP_BUNDLE/Contents/MacOS/$APP_NAME"
BUNDLE_ID="com.kimtoma.openneko"

usage() {
  echo "usage: $0 [run|--debug|--logs|--telemetry|--verify]" >&2
}

build_app() {
  cd "$ROOT_DIR"
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
}

stop_app() {
  pkill -x "$APP_NAME" >/dev/null 2>&1 || true
}

open_app() {
  local open_args=(-n)
  local env_name
  local env_value
  for env_name in \
    OPENNEKO_PORT \
    OPENNEKO_SETTINGS_PATH \
    OPENNEKO_OPEN_SETTINGS \
    OPENNEKO_SETTINGS_SNAPSHOT \
    OPENNEKO_DEBUG_SETTINGS_MUTATION \
    OPENNEKO_UPDATE_ROOT; do
    if env_value="$(printenv "$env_name")"; then
      open_args+=(--env "$env_name=$env_value")
    fi
  done
  /usr/bin/open "${open_args[@]}" "$APP_BUNDLE"
}

run_app_binary() {
  "$APP_BINARY"
}

verify_app() {
  local port="${OPENNEKO_PORT:-48910}"
  OPENNEKO_PORT="$port" "$APP_BINARY" >/tmp/openneko-build-run.log 2>&1 &
  local pid=$!
  trap 'kill "$pid" >/dev/null 2>&1 || true' EXIT

  for _ in 1 2 3 4 5 6 7 8 9 10; do
    if /usr/bin/curl -fsS "http://127.0.0.1:$port/health" >/dev/null 2>&1; then
      /usr/bin/curl -fsS "http://127.0.0.1:$port/anim" >/dev/null
      kill "$pid" >/dev/null 2>&1 || true
      trap - EXIT
      return 0
    fi
    sleep 0.5
  done

  tail -40 /tmp/openneko-build-run.log >&2 || true
  return 1
}

stop_app
build_app

case "$MODE" in
  run)
    open_app
    ;;
  --debug|debug)
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\" || process == \"$APP_NAME\""
    ;;
  --verify|verify)
    verify_app
    ;;
  *)
    usage
    exit 2
    ;;
esac
