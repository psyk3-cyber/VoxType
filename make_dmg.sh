#!/bin/bash
# Packages build/VoxType.app into a distributable DMG.
# Run ./build_app.sh first.
set -euo pipefail
cd "$(dirname "$0")"

APP="build/VoxType.app"
VERSION=$(defaults read "$(pwd)/$APP/Contents/Info" CFBundleShortVersionString 2>/dev/null || echo "1.0.0")
DMG="build/VoxType-$VERSION.dmg"
STAGING="build/dmg-staging"

[ -d "$APP" ] || { echo "✗ $APP not found — run ./build_app.sh first."; exit 1; }

echo "▸ Staging…"
rm -rf "$STAGING" "$DMG"
mkdir -p "$STAGING"
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

echo "▸ Creating DMG…"
hdiutil create -volname "VoxType" -srcfolder "$STAGING" -ov -format UDZO "$DMG"
rm -rf "$STAGING"

echo ""
echo "✓ Created $DMG"
echo ""
echo "Upload this to a GitHub Release. Since it's not notarized, tell users:"
echo "  Right-click VoxType.app → Open → Open (first launch only),"
echo "  or: xattr -dr com.apple.quarantine /Applications/VoxType.app"
