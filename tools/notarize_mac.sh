#!/usr/bin/env bash
# Sign, notarize and staple the macOS build exported by tools/build.sh.
#   tools/notarize_mac.sh build/<date>-<commit>/UnderTwoSkies-macOS.zip
# Writes UnderTwoSkies-macOS-notarized.zip (+ the notary log) next to the input.
#
# Needs, on this Mac:
#  - the "Developer ID Application: Visarut Sankham (79QFYKTJMN)" identity in the keychain
#  - a notarytool keychain profile named "undertwoskies-notary", created once with
#      xcrun notarytool store-credentials "undertwoskies-notary" --key <AuthKey.p8> --key-id <ID> --issuer <UUID>
# No credential values live in this repo or this script.
set -euo pipefail
IN="${1:?usage: tools/notarize_mac.sh <UnderTwoSkies-macOS.zip>}"
IDENTITY="${IDENTITY:-Developer ID Application: Visarut Sankham (79QFYKTJMN)}"
PROFILE="${NOTARY_PROFILE:-undertwoskies-notary}"
APP_NAME="Under Two Skies.app"
OUT_DIR="$(cd "$(dirname "$IN")" && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

ditto -x -k "$IN" "$WORK"
APP="$WORK/$APP_NAME"
# Single universal binary + .pck: one bundle signature covers it (no --deep).
# Hardened runtime + secure timestamp; GDScript needs no JIT entitlement.
codesign --sign "$IDENTITY" --options runtime --timestamp --force "$APP"
codesign --verify --strict --verbose=2 "$APP"
BOOT_LOG="$OUT_DIR/signed-boot.log"
"$APP/Contents/MacOS/Under Two Skies" --headless --verbose --fixed-fps 60 --quit-after 90 --log-file "$BOOT_LOG" >"$OUT_DIR/signed-boot-console.log" 2>&1 \
	|| { echo "signed app failed to boot; see $BOOT_LOG"; exit 1; }
if grep -Eq 'SCRIPT ERROR|Parse Error|ERROR:' "$BOOT_LOG" "$OUT_DIR/signed-boot-console.log"; then
	echo "signed app reported runtime errors; see $BOOT_LOG"
	exit 1
fi

ditto -c -k --keepParent "$APP" "$WORK/submit.zip"
RESULT="$(xcrun notarytool submit "$WORK/submit.zip" --keychain-profile "$PROFILE" --wait --output-format json)"
echo "$RESULT"
ID="$(python3 -c 'import json,sys; print(json.loads(sys.argv[1])["id"])' "$RESULT")"
STATUS="$(python3 -c 'import json,sys; print(json.loads(sys.argv[1])["status"])' "$RESULT")"
xcrun notarytool log "$ID" --keychain-profile "$PROFILE" "$OUT_DIR/notary-log-$ID.json" >/dev/null
[ "$STATUS" = "Accepted" ] || { echo "notarization $STATUS; see $OUT_DIR/notary-log-$ID.json"; exit 1; }

xcrun stapler staple "$APP"
xcrun stapler validate "$APP"
spctl --assess --type execute --verbose=2 "$APP"

OUT="$OUT_DIR/UnderTwoSkies-macOS-notarized.zip"
rm -f "$OUT"
ditto -c -k --keepParent "$APP" "$OUT"
shasum -a 256 "$OUT"
echo "Notarized: $OUT (submission $ID)"
