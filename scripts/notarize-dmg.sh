#!/bin/bash
# Notarizes and staples build/DesktopCat.dmg (run scripts/build-dmg.sh first).
# Uses the same notarytool credentials as scripts/notarize.sh — see that file
# for how to register them.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DMG="$ROOT/build/DesktopCat.dmg"
PROFILE="${NOTARY_PROFILE:-desktopcat-notary}"

if [ ! -f "$DMG" ]; then
    echo "error: $DMG not found — run scripts/build-dmg.sh first" >&2
    exit 1
fi

echo "==> Submitting DMG to Apple notary service (profile: $PROFILE)"
# See notarize.sh for why this is an if/else instead of an optional-args array.
if [ -n "${NOTARY_KEYCHAIN:-}" ]; then
    xcrun notarytool submit "$DMG" --keychain-profile "$PROFILE" --keychain "$NOTARY_KEYCHAIN" --wait
else
    xcrun notarytool submit "$DMG" --keychain-profile "$PROFILE" --wait
fi

echo "==> Stapling ticket to DMG"
xcrun stapler staple "$DMG"

echo "==> Re-verifying with Gatekeeper"
spctl --assess --verbose --type open --context context:primary-signature "$DMG"

echo "==> Notarized: $DMG"
