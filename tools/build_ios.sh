#!/usr/bin/env bash
# Export, archive and package an iOS/iPadOS candidate (IPA for TestFlight / App Store)
# into a fresh build/<date-time>-<commit>-<run>-ios/. Mirrors tools/build.sh discipline:
# committed runtime sources only, frozen git-archive snapshot, engine errors rejected.
#
#   tools/build_ios.sh                 # export + archive + IPA (app-store-connect method)
#   tools/build_ios.sh --project-only  # stop after the Xcode project (open it in Xcode)
#   tools/build_ios.sh --dev-app       # also build a Debug .app for a paired device
#
# Needs Godot 4.7.2 + export templates (ios.zip), Xcode, and both Apple Development and
# Apple Distribution certificates for TEAM_ID in the login keychain. Automatic signing
# (-allowProvisioningUpdates) creates/refreshes the App ID and profiles.
#
# Upload (manual, owner-gated): xcrun altool --upload-app -f <ipa> -t ios --apiKey ... --apiIssuer ...
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
TEAM_ID="${TEAM_ID:-79QFYKTJMN}"
SCHEME="UnderTwoSkies"
PROJECT_ONLY=0; DEV_APP=0
for a in "$@"; do
  case "$a" in
    --project-only) PROJECT_ONLY=1 ;;
    --dev-app) DEV_APP=1 ;;
    *) echo "unknown option $a" >&2; exit 1 ;;
  esac
done
SOURCE_PATHS=(project.godot export_presets.cfg scripts ui scenes assets localization ios tools/build.sh tools/build_ios.sh)
if ! git diff --quiet -- "${SOURCE_PATHS[@]}" || ! git diff --cached --quiet -- "${SOURCE_PATHS[@]}" \
  || [ -n "$(git ls-files --others --exclude-standard -- "${SOURCE_PATHS[@]}")" ]; then
  echo "Commit the release source and assets before building (uncommitted runtime files found)." >&2
  exit 1
fi
COMMIT="$(git rev-parse HEAD)"
STAMP="$(TZ=Asia/Bangkok date +%Y%m%d-%H%M%S)-$(git rev-parse --short HEAD)"
mkdir -p build; touch build/.gdignore
OUT="$(mktemp -d "build/$STAMP-ios-XXXXXX")"; OUT="$(cd "$OUT" && pwd)"
SOURCE="$OUT/source"; mkdir -p "$SOURCE"
git archive "$COMMIT" | tar -xf - -C "$SOURCE"

run_engine() {
  local log="$1"; shift
  if ! "$GODOT" "$@" >"$log" 2>&1; then cat "$log" >&2; echo "Engine failed; see $log" >&2; return 1; fi
  if grep -Eq 'SCRIPT ERROR|Parse Error|ERROR:' "$log"; then cat "$log" >&2; echo "Engine errors; see $log" >&2; return 1; fi
}
run_engine "$OUT/import.log" --headless --path "$SOURCE" --import
XC="$OUT/xcode"; mkdir -p "$XC"
echo "== iOS -> $XC/$SCHEME.xcodeproj"
# Release export: the preset has export_project_only=true, so Godot writes the Xcode
# project + .pck and we drive xcodebuild ourselves (reproducible, loggable).
run_engine "$OUT/export-iOS.log" --headless --path "$SOURCE" --export-release "iOS" "$XC/$SCHEME.xcodeproj"
[ -d "$XC/$SCHEME.xcodeproj" ] && [ -s "$XC/$SCHEME.pck" ] || { echo "Missing Xcode project or PCK" >&2; exit 1; }
# Every exported resource must load from the pack itself (exclude_filter safety net).
echo "== pack load check"
( cd /tmp && "$GODOT" --headless --main-pack "$XC/$SCHEME.pck" --script "$SOURCE/tools/check_pack_loads.gd" >"$OUT/pack-loads.log" 2>&1 ) \
  || { cat "$OUT/pack-loads.log" >&2; echo "Pack load check failed; see $OUT/pack-loads.log" >&2; exit 1; }
grep LOADALL "$OUT/pack-loads.log"
if [ "$PROJECT_ONLY" = 1 ]; then echo "Xcode project in $XC"; exit 0; fi

# Xcode notes (verified 2026-10-12, Xcode 27.0):
# 1. Godot's Release config hardcodes CODE_SIGN_IDENTITY="Apple Distribution"; automatic
#    signing requires the Development identity at archive time (re-signed at export).
# 2. exportArchive runs /usr/bin/rsync (openrsync), which spawns a server `rsync` via PATH.
#    A Homebrew rsync on PATH rejects openrsync's --extended-attributes -> "Copy failed".
#    Run xcodebuild with a system-only PATH.
XPATH=/usr/bin:/bin:/usr/sbin:/sbin
xb() { env PATH="$XPATH" xcodebuild "$@"; }
cd "$XC"
if [ "$DEV_APP" = 1 ]; then
  echo "== Debug device app"
  xb -project "$SCHEME.xcodeproj" -scheme "$SCHEME" -configuration Debug -destination 'generic/platform=iOS' \
     -derivedDataPath ./dd -allowProvisioningUpdates DEVELOPMENT_TEAM="$TEAM_ID" CODE_SIGN_STYLE=Automatic build \
     >"$OUT/xcodebuild-debug.log" 2>&1 || { tail -40 "$OUT/xcodebuild-debug.log" >&2; exit 1; }
  grep -q 'BUILD SUCCEEDED' "$OUT/xcodebuild-debug.log"
  echo "   $(find dd/Build/Products -name "$SCHEME.app" -path '*iphoneos*' | head -1)"
fi
echo "== Release archive"
xb -project "$SCHEME.xcodeproj" -scheme "$SCHEME" -configuration Release -destination 'generic/platform=iOS' \
   -derivedDataPath ./dd -archivePath "./$SCHEME.xcarchive" -allowProvisioningUpdates \
   DEVELOPMENT_TEAM="$TEAM_ID" CODE_SIGN_STYLE=Automatic CODE_SIGN_IDENTITY="Apple Development" archive \
   >"$OUT/xcodebuild-archive.log" 2>&1 || { tail -40 "$OUT/xcodebuild-archive.log" >&2; exit 1; }
grep -q 'ARCHIVE SUCCEEDED' "$OUT/xcodebuild-archive.log"
cat >ExportOptions.plist <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>method</key><string>app-store-connect</string>
  <key>destination</key><string>export</string>
  <key>teamID</key><string>$TEAM_ID</string>
  <key>signingStyle</key><string>automatic</string>
  <key>uploadSymbols</key><true/>
  <key>stripSwiftSymbols</key><true/>
</dict></plist>
PLIST
echo "== Export IPA (app-store-connect)"
xb -exportArchive -archivePath "./$SCHEME.xcarchive" -exportPath "$OUT/ipa" -exportOptionsPlist ExportOptions.plist \
   -allowProvisioningUpdates >"$OUT/xcodebuild-export.log" 2>&1 || { tail -40 "$OUT/xcodebuild-export.log" >&2; exit 1; }
grep -q 'EXPORT SUCCEEDED' "$OUT/xcodebuild-export.log"
IPA="$OUT/ipa/$SCHEME.ipa"; [ -s "$IPA" ] || { echo "Missing IPA" >&2; exit 1; }
cd "$OUT/.."
if [ "$(git rev-parse HEAD)" != "$COMMIT" ] \
  || ! git diff --quiet -- "${SOURCE_PATHS[@]}" || ! git diff --cached --quiet -- "${SOURCE_PATHS[@]}" \
  || [ -n "$(git ls-files --others --exclude-standard -- "${SOURCE_PATHS[@]}")" ]; then
  echo "Release source changed during export; candidate is not qualified." >&2; exit 1
fi
python3 - "$OUT" "$COMMIT" "$("$GODOT" --version)" "$IPA" "$(env PATH="$XPATH" xcodebuild -version | tr '\n' ' ')" <<'PY'
import hashlib, json, sys
from pathlib import Path
ipa = Path(sys.argv[4])
Path(sys.argv[1], 'source-manifest.json').write_text(json.dumps({
    'commit': sys.argv[2], 'godot': sys.argv[3], 'xcode': sys.argv[5].strip(), 'presets': ['iOS'],
    'ipa': ipa.name, 'ipa_bytes': ipa.stat().st_size,
    'ipa_sha256': hashlib.sha256(ipa.read_bytes()).hexdigest(),
    'export_method': 'app-store-connect', 'runtime_sources_committed': True, 'source_snapshot': 'git archive',
}, indent=2) + '\n')
PY
echo "iOS candidate in $OUT:"; ls -lh "$OUT/ipa"; cat "$OUT/source-manifest.json"
