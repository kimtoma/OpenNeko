#!/usr/bin/env bash
# Builds the Windows release packages from Linux or macOS (or Git Bash):
#   windows/artifacts/OpenNeko-Windows-x64-<version>.zip  portable, unzip and run
#   windows/artifacts/OpenNeko-Windows-x64-<version>.msi  per-user installer
# Needs the .NET 8 SDK; the MSI step also needs wixl (apt install wixl /
# brew install msitools) and is skipped when wixl is missing.
set -euo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"
win="$root/windows"
out="$win/artifacts"
publish="$out/publish"
version="$(sed -n 's:.*<Version>\(.*\)</Version>.*:\1:p' "$win/Directory.Build.props" | head -n1)"
name="OpenNeko-Windows-x64-$version"

rm -rf "$publish" "$out/$name.zip" "$out/$name.msi"
mkdir -p "$out"

dotnet publish "$win/src/OpenNeko.Windows" -c Release -r win-x64 \
  --self-contained true -p:PublishSingleFile=true \
  -p:IncludeNativeLibrariesForSelfExtract=true -p:DebugType=none \
  -o "$publish"

(cd "$publish" && zip -qr "$out/$name.zip" .)
echo "zip: $out/$name.zip"

if ! command -v wixl >/dev/null 2>&1; then
  echo "wixl not found; skipping the MSI (apt install wixl / brew install msitools)"
  exit 0
fi

content="$out/content.wxs"
(cd "$publish" && find Assets Resources -type f | LC_ALL=C sort |
  wixl-heat --prefix "" --directory-ref INSTALLDIR --component-group AppContent \
    --var var.SourceDir > "$content")
wixl -a x64 -D Version="$version" -D SourceDir="$publish" \
  -o "$out/$name.msi" "$win/installer/OpenNeko.wxs" "$content"
rm -f "$content"
echo "msi: $out/$name.msi"
