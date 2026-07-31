#!/bin/bash
# Packages the already-built build/DesktopCat.app into a distributable .dmg
# with an /Applications shortcut alongside it — the standard drag-to-install
# macOS UX, and (more importantly for us) it trains users to actually move the
# app into Applications instead of double-clicking it straight out of
# Downloads, which triggers App Translocation and breaks self-update/uninstall.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

APP_NAME="DesktopCat"
BUNDLE="$ROOT/build/$APP_NAME.app"
DMG="$ROOT/build/$APP_NAME.dmg"
STAGING="$ROOT/build/dmg-staging"

if [ ! -d "$BUNDLE" ]; then
    echo "error: $BUNDLE not found — run scripts/build-app.sh first" >&2
    exit 1
fi
if [ -z "${SIGN_IDENTITY:-}" ]; then
    echo "error: set SIGN_IDENTITY to your own \"Developer ID Application: <name> (<team id>)\" identity" >&2
    exit 1
fi

echo "==> Staging DMG contents"
rm -rf "$STAGING" "$DMG"
mkdir -p "$STAGING"
cp -R "$BUNDLE" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

echo "==> Creating $DMG"
hdiutil create -volname "$APP_NAME" -srcfolder "$STAGING" -ov -format UDZO "$DMG"
rm -rf "$STAGING"

echo "==> Codesigning DMG"
codesign --force --sign "$SIGN_IDENTITY" "$DMG"

echo "==> Verifying signature"
codesign --verify --verbose=2 "$DMG"

echo "==> Done: $DMG"
