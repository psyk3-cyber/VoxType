#!/bin/bash
# Builds VoxType.app from the Swift package.
# Requires: Xcode or Command Line Tools (xcode-select --install)
set -euo pipefail
cd "$(dirname "$0")"

echo "▸ Building (release)…"
# Try a universal binary (Apple Silicon + Intel); fall back to native arch.
if swift build -c release --arch arm64 --arch x86_64 2>/dev/null; then
    BIN=".build/apple/Products/Release/VoxType"
    echo "  Universal binary (arm64 + x86_64)."
else
    swift build -c release
    BIN=".build/release/VoxType"
    echo "  Native-arch binary ($(uname -m))."
fi

APP="build/VoxType.app"

echo "▸ Assembling app bundle…"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/VoxType"
cp Info.plist "$APP/Contents/Info.plist"

# App icon: build AppIcon.icns from the iconset if needed.
if [ ! -f AppIcon.icns ] && [ -d AppIcon.iconset ]; then
    echo "▸ Generating AppIcon.icns…"
    iconutil -c icns AppIcon.iconset -o AppIcon.icns
fi
if [ -f AppIcon.icns ]; then
    cp AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
else
    echo "  (No AppIcon.icns — run: python3 make_icon.py, then rebuild.)"
fi

echo "▸ Signing (ad-hoc)…"
codesign --force --sign - "$APP"

echo ""
echo "✓ Built $APP"
echo ""
echo "Next steps:"
echo "  1. Move it to /Applications:   mv -f $APP /Applications/"
echo "  2. Launch it, then grant Microphone, Speech Recognition, and"
echo "     Accessibility permissions when prompted."
echo "  3. System Settings → Keyboard → 'Press 🌐 key to' → Do Nothing."
echo "  4. Hold fn and speak. Release to insert text."
