#!/bin/bash
# Build our Tahoe-fixed Ice fork (Release), deep ad-hoc re-sign so the
# embedded Sparkle.framework loads, and install into /Applications.
set -euo pipefail
cd "$(dirname "$0")"

CONFIG="${1:-Release}"
DERIVED="build-release"
LOG="/tmp/ice-build-install.log"

echo "==> Building ($CONFIG)…"
rm -rf "$DERIVED"
xcodebuild -project Ice.xcodeproj -scheme Ice -configuration "$CONFIG" \
  -destination 'platform=macOS' -derivedDataPath "$DERIVED" \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=YES CODE_SIGNING_ALLOWED=YES \
  build > "$LOG" 2>&1
grep -q "BUILD SUCCEEDED" "$LOG" || { echo "BUILD FAILED — tail:"; grep -E "error:" "$LOG" | head; exit 1; }
echo "    BUILD SUCCEEDED"

APP=$(find "$DERIVED/Build/Products/$CONFIG" -name "Ice.app" -maxdepth 2 | head -1)
echo "==> Deep ad-hoc re-sign…"
codesign --force --deep --sign - "$APP" >/dev/null 2>&1
codesign -v --deep --strict "$APP" && echo "    signature valid"

echo "==> Installing to /Applications…"
osascript -e 'tell application "Ice" to quit' 2>/dev/null || true
pkill -x Ice 2>/dev/null || true
sleep 1
rm -rf /Applications/Ice.app
cp -R "$APP" /Applications/Ice.app
xattr -dr com.apple.quarantine /Applications/Ice.app 2>/dev/null || true

echo "==> Launching…"
open -a /Applications/Ice.app
sleep 3
if pgrep -x Ice >/dev/null; then
  echo "    Ice RUNNING — v$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' /Applications/Ice.app/Contents/Info.plist)"
else
  echo "    NOT running — check ~/Library/Logs/DiagnosticReports/Ice-*.ips"
  exit 1
fi
