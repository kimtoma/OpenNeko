#!/usr/bin/env bash
# openNeko macOS installer (source checkout + bundled Electron).
#
# One-liner:
#   curl -fsSL https://github.com/kimtoma/openNeko/releases/latest/download/openneko-install.sh | bash
#
# Options:
#   OPENNEKO_REF=<branch/tag>       default: main
#   OPENNEKO_DIR=<install path>     default: ~/Applications/openNeko
#   OPENNEKO_NO_AUTOSTART=1         skip LaunchAgent login autostart
set -euo pipefail

REPO="https://github.com/kimtoma/openNeko.git"
REF="${OPENNEKO_REF:-main}"
DIR="${OPENNEKO_DIR:-$HOME/Applications/openNeko}"
LABEL="com.kimtoma.openneko"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"

say() { printf '\033[1;36m> %s\033[0m\n' "$1"; }
err() { printf '\033[1;31m! %s\033[0m\n' "$1" >&2; }

if [ "$(uname)" != "Darwin" ]; then err "This installer is for macOS."; exit 1; fi

if ! command -v git >/dev/null 2>&1; then
  err "git is missing. Install the Xcode command line tools with: xcode-select --install"
  exit 1
fi

if ! command -v node >/dev/null 2>&1 || ! command -v npm >/dev/null 2>&1; then
  err "Node.js and npm are required. Install Node 22.12+ from https://nodejs.org or Homebrew."
  exit 1
fi
if ! node -e 'const [maj,min]=process.versions.node.split(".").map(Number); process.exit(maj > 22 || (maj === 22 && min >= 12) ? 0 : 1)'; then
  err "Node 22.12+ is required (current: $(node -v))."
  exit 1
fi

if [ -d "$DIR/.git" ]; then
  say "Updating existing install: $DIR"
  git -C "$DIR" fetch --depth 1 origin "$REF"
  git -C "$DIR" checkout -f "$REF"
  git -C "$DIR" reset --hard "origin/$REF"
else
  say "Cloning: $REPO ($REF) -> $DIR"
  mkdir -p "$(dirname "$DIR")"
  git clone --depth 1 --branch "$REF" "$REPO" "$DIR"
fi

say "Installing dependencies"
( cd "$DIR" && npm install --no-fund --no-audit )
say "Building renderer bundles"
( cd "$DIR" && npm run build )

ELECTRON_BIN="$DIR/node_modules/electron/dist/Electron.app/Contents/MacOS/Electron"
if [ ! -x "$ELECTRON_BIN" ]; then err "Electron binary not found: $ELECTRON_BIN"; exit 1; fi

if [ "${OPENNEKO_NO_AUTOSTART:-0}" != "1" ]; then
  say "Registering login autostart: $PLIST"
  mkdir -p "$HOME/Library/LaunchAgents"
  cat > "$PLIST" <<PLISTEOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>$ELECTRON_BIN</string>
    <string>$DIR</string>
  </array>
  <key>WorkingDirectory</key><string>$DIR</string>
  <key>RunAtLoad</key><true/>
  <key>ProcessType</key><string>Interactive</string>
  <key>StandardOutPath</key><string>/tmp/openneko.out.log</string>
  <key>StandardErrorPath</key><string>/tmp/openneko.err.log</string>
</dict>
</plist>
PLISTEOF
  launchctl unload "$PLIST" 2>/dev/null || true
  launchctl load -w "$PLIST"
else
  say "Skipping autostart; launching once"
  ( cd "$DIR" && "$ELECTRON_BIN" "$DIR" >/tmp/openneko.out.log 2>&1 & )
fi

cat <<DONE

openNeko installed.

Recommended setup:
  - Set OPENAI_API_KEY in your shell or add it in openNeko Settings.
  - On macOS, allow openNeko or Electron under Accessibility and Input Monitoring
    if you want typing reactions. Key contents are never read.

Manage:
  - Quit: tray/menu bar icon -> quit
  - Disable autostart: launchctl unload "$PLIST" && rm "$PLIST"
  - Remove app: disable autostart, then rm -rf "$DIR"

Install path: $DIR
DONE
