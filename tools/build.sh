#!/usr/bin/env bash
# Export playtest builds (PRD_UPDATE_v1.1 P0-8) into build/<date>-<commit>/.
# Needs Godot 4.7.2 and its export templates (Editor > Manage Export Templates).
#   tools/build.sh            # all presets
#   tools/build.sh Linux      # one preset: macOS | Linux | Windows
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
STAMP="$(date +%Y%m%d)-$(git rev-parse --short HEAD 2>/dev/null || echo nogit)"
OUT="build/$STAMP"
PRESETS=("${@:-macOS Linux Windows}")
read -r -a PRESETS <<< "${PRESETS[*]}"
mkdir -p "$OUT"
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
for p in "${PRESETS[@]}"; do
  case "$p" in
    macOS)   target="$OUT/UnderTwoSkies-macOS.zip" ;;
    Linux)   mkdir -p "$OUT/UnderTwoSkies-Linux";   target="$OUT/UnderTwoSkies-Linux/UnderTwoSkies.x86_64" ;;
    Windows) mkdir -p "$OUT/UnderTwoSkies-Windows"; target="$OUT/UnderTwoSkies-Windows/UnderTwoSkies.exe" ;;
    *) echo "unknown preset $p"; exit 1 ;;
  esac
  echo "== $p -> $target"
  "$GODOT" --headless --path . --export-release "$p" "$target"
done
if [ -d "$OUT/UnderTwoSkies-Linux" ]; then (cd "$OUT" && zip -qr UnderTwoSkies-Linux.zip UnderTwoSkies-Linux); fi
if [ -d "$OUT/UnderTwoSkies-Windows" ]; then (cd "$OUT" && zip -qr UnderTwoSkies-Windows.zip UnderTwoSkies-Windows); fi
echo "Builds in $OUT:"; ls -lh "$OUT"
