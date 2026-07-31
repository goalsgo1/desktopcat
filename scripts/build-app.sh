#!/bin/bash
# Builds DesktopCat.app and codesigns it with the local "Developer ID Application"
# identity. Notarization is a separate step (scripts/notarize.sh) since it needs
# network access and stored credentials.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

APP_NAME="DesktopCat"
BUNDLE="$ROOT/build/$APP_NAME.app"
if [ -z "${SIGN_IDENTITY:-}" ]; then
    echo "error: set SIGN_IDENTITY to your own \"Developer ID Application: <name> (<team id>)\" identity" >&2
    exit 1
fi

echo "==> swift build -c release"
swift build -c release

echo "==> Assembling $APP_NAME.app"
rm -rf "$BUNDLE"
mkdir -p "$BUNDLE/Contents/MacOS" "$BUNDLE/Contents/Resources"
cp ".build/release/$APP_NAME" "$BUNDLE/Contents/MacOS/$APP_NAME"
cp "Resources/Info.plist" "$BUNDLE/Contents/Info.plist"
if [ -n "${APP_VERSION:-}" ]; then
    /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $APP_VERSION" "$BUNDLE/Contents/Info.plist"
fi

echo "==> Codesigning with: $SIGN_IDENTITY"
codesign --force --deep --options runtime \
    --entitlements "$ROOT/entitlements.plist" \
    --sign "$SIGN_IDENTITY" \
    "$BUNDLE"

echo "==> Verifying signature"
codesign --verify --deep --strict --verbose=2 "$BUNDLE"
spctl --assess --type execute --verbose "$BUNDLE" || echo "(spctl will fail until notarized — expected at this stage)"

echo "==> Done: $BUNDLE"
