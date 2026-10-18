#!/bin/bash
# Build WheelDrop Diagnostic (Phase 0) and package as .app
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="WheelDropDiag"
APP_BUNDLE="$SCRIPT_DIR/$APP_NAME.app"
BUILD_DIR="$SCRIPT_DIR/.build/release"

echo "=== WheelDrop Diagnostic — build ==="
echo "Dir: $SCRIPT_DIR"
echo ""

# Build release binary
cd "$SCRIPT_DIR"
swift build -c release

BINARY="$BUILD_DIR/$APP_NAME"
if [[ ! -f "$BINARY" ]]; then
    echo "ERROR: binary not found at $BINARY"
    exit 1
fi

# Assemble .app bundle
echo ""
echo "Assembling $APP_NAME.app..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$BINARY" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
cp "$SCRIPT_DIR/Resources/Info.plist" "$APP_BUNDLE/Contents/"

# Ad-hoc sign (development only — no Developer ID required)
echo "Signing ad-hoc..."
codesign --sign - --force --deep "$APP_BUNDLE"

echo ""
echo "Build complete: $APP_BUNDLE"
arch_info=$(file "$APP_BUNDLE/Contents/MacOS/$APP_NAME")
echo "Architecture: $arch_info"
echo ""
echo "Launch:"
echo "  open \"$APP_BUNDLE\""
echo ""
echo "NOTE: On first launch macOS may show 'unidentified developer'."
echo "If blocked, go to System Settings → Privacy & Security → Open Anyway."
echo ""
echo "After launch:"
echo "  1. Look for the ⊘ icon in the menu bar."
echo "  2. macOS will prompt for Accessibility permission — grant it."
echo "  3. The icon changes to ◉ when monitoring is active."
echo "  4. See README_DIAG.md for the manual test procedure."
