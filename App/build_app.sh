#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP="WheelDrop"
BUNDLE="$SCRIPT_DIR/$APP.app"

echo "=== WheelDrop — build ==="
cd "$SCRIPT_DIR"
swift build -c release

BIN="$SCRIPT_DIR/.build/release/$APP"
[[ -f "$BIN" ]] || { echo "ERROR: binary not found"; exit 1; }

rm -rf "$BUNDLE"
mkdir -p "$BUNDLE/Contents/MacOS" "$BUNDLE/Contents/Resources"
cp "$BIN" "$BUNDLE/Contents/MacOS/$APP"
cp "$SCRIPT_DIR/Resources/Info.plist" "$BUNDLE/Contents/"
# Icons
[[ -f "$SCRIPT_DIR/Resources/AppIcon.icns" ]] && \
    cp "$SCRIPT_DIR/Resources/AppIcon.icns" "$BUNDLE/Contents/Resources/"
[[ -f "$SCRIPT_DIR/Resources/StatusIcon.png" ]] && \
    cp "$SCRIPT_DIR/Resources/StatusIcon.png"    "$BUNDLE/Contents/Resources/"
[[ -f "$SCRIPT_DIR/Resources/StatusIcon@2x.png" ]] && \
    cp "$SCRIPT_DIR/Resources/StatusIcon@2x.png" "$BUNDLE/Contents/Resources/"

echo "Signing ad-hoc..."
codesign --sign - --force --deep "$BUNDLE"

echo ""
echo "Done: $BUNDLE"
file "$BUNDLE/Contents/MacOS/$APP"
echo ""
echo "  open \"$BUNDLE\""
