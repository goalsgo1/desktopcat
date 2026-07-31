#!/bin/bash
# Notarizes and staples build/DesktopCat.app. Requires notarization credentials
# stored once via:
#   xcrun notarytool store-credentials "desktopcat-notary" \
#     --apple-id "<your Apple ID email>" \
#     --team-id "<your team id>"
# (it will prompt for the app-specific password interactively — run that command
# yourself in Terminal so the password never has to be typed anywhere else)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUNDLE="$ROOT/build/DesktopCat.app"
PROFILE="${NOTARY_PROFILE:-desktopcat-notary}"
ZIP="$ROOT/build/DesktopCat.zip"

if [ ! -d "$BUNDLE" ]; then
    echo "error: $BUNDLE not found — run scripts/build-app.sh first" >&2
    exit 1
fi

echo "==> Zipping for submission"
rm -f "$ZIP"
ditto -c -k --keepParent "$BUNDLE" "$ZIP"

echo "==> Submitting to Apple notary service (profile: $PROFILE)"
# bash 3.2 (macOS's stock /bin/bash) treats "${ARR[@]}" on a zero-element array
# as an unbound-variable error under `set -u`, so branch instead of building an
# optional-args array — path to a specific keychain to look the profile up in
# (e.g. a CI temporary keychain); defaults to the normal keychain search list.
if [ -n "${NOTARY_KEYCHAIN:-}" ]; then
    xcrun notarytool submit "$ZIP" --keychain-profile "$PROFILE" --keychain "$NOTARY_KEYCHAIN" --wait
else
    xcrun notarytool submit "$ZIP" --keychain-profile "$PROFILE" --wait
fi

echo "==> Stapling ticket"
xcrun stapler staple "$BUNDLE"

echo "==> Re-verifying with Gatekeeper"
spctl --assess --type execute --verbose "$BUNDLE"

echo "==> Notarized: $BUNDLE"
