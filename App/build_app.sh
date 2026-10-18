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

echo "Signing ad-hoc..."
codesign --sign - --force --deep "$BUNDLE"

echo ""
echo "Done: $BUNDLE"
file "$BUNDLE/Contents/MacOS/$APP"
echo ""
echo "  open \"$BUNDLE\""
