#!/usr/bin/env bash
# Export playtest builds into a fresh build/<date-time>-<commit>-<run>/.
# Needs Godot 4.7.2 and its export templates (Editor > Manage Export Templates).
#   tools/build.sh            # all presets
#   tools/build.sh Linux      # one preset: macOS | Linux | Windows
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
# These paths determine shipped bytes; unrelated planning work can stay local.
SOURCE_PATHS=(project.godot export_presets.cfg scripts ui scenes assets localization tools/build.sh tools/notarize_mac.sh)
if ! git diff --quiet -- "${SOURCE_PATHS[@]}" || ! git diff --cached --quiet -- "${SOURCE_PATHS[@]}" \
  || [ -n "$(git ls-files --others --exclude-standard -- "${SOURCE_PATHS[@]}")" ]; then
  echo "Commit the release source and assets before building (uncommitted runtime files found)." >&2
  exit 1
fi
COMMIT="$(git rev-parse HEAD)"
STAMP="$(TZ=Asia/Bangkok date +%Y%m%d-%H%M%S)-$(git rev-parse --short HEAD)"
if [ "$#" -eq 0 ]; then PRESETS=(macOS Linux Windows); else PRESETS=("$@"); fi
for p in "${PRESETS[@]}"; do
  case "$p" in macOS|Linux|Windows) ;; *) echo "unknown preset $p" >&2; exit 1 ;; esac
done
mkdir -p build
touch build/.gdignore
OUT="$(mktemp -d "build/$STAMP-XXXXXX")"
OUT="$(cd "$OUT" && pwd)"
# Swarm agents share the checkout. Export a frozen committed snapshot, never
# partly old and partly new files if another agent edits during an export.
SOURCE="$OUT/source"
mkdir -p "$SOURCE"
git archive "$COMMIT" | tar -xf - -C "$SOURCE"
run_engine() {
  local log="$1"; shift
  if ! "$GODOT" "$@" >"$log" 2>&1; then
    cat "$log" >&2
    echo "Engine failed; see $log" >&2
    return 1
  fi
  # Godot can report script/export errors while returning exit 0.
  if grep -Eq 'SCRIPT ERROR|Parse Error|ERROR:' "$log"; then
    cat "$log" >&2
    echo "Engine errors; see $log" >&2
    return 1
  fi
}
run_engine "$OUT/import.log" --headless --path "$SOURCE" --import
for p in "${PRESETS[@]}"; do
  case "$p" in
    macOS)   target="$OUT/UnderTwoSkies-macOS.zip" ;;
    Linux)   mkdir -p "$OUT/UnderTwoSkies-Linux";   target="$OUT/UnderTwoSkies-Linux/UnderTwoSkies.x86_64" ;;
    Windows) mkdir -p "$OUT/UnderTwoSkies-Windows"; target="$OUT/UnderTwoSkies-Windows/UnderTwoSkies.exe" ;;
    *) echo "unknown preset $p"; exit 1 ;;
  esac
  echo "== $p -> $target"
  run_engine "$OUT/export-$p.log" --headless --path "$SOURCE" --export-release "$p" "$target"
  [ -s "$target" ] || { echo "Missing or empty export: $target" >&2; exit 1; }
  case "$p" in
    macOS) unzip -tq "$target" >/dev/null ;;
    Linux) (cd "$OUT" && zip -qr UnderTwoSkies-Linux.zip UnderTwoSkies-Linux) ;;
    Windows) (cd "$OUT" && zip -qr UnderTwoSkies-Windows.zip UnderTwoSkies-Windows) ;;
  esac
done
if [ "$(git rev-parse HEAD)" != "$COMMIT" ] \
  || ! git diff --quiet -- "${SOURCE_PATHS[@]}" || ! git diff --cached --quiet -- "${SOURCE_PATHS[@]}" \
  || [ -n "$(git ls-files --others --exclude-standard -- "${SOURCE_PATHS[@]}")" ]; then
  echo "Release source changed during export; candidate is not qualified." >&2
  exit 1
fi
python3 - "$OUT" "$COMMIT" "$("$GODOT" --version)" "${PRESETS[@]}" <<'PY'
import json, sys
from pathlib import Path
Path(sys.argv[1], 'source-manifest.json').write_text(json.dumps({
    'commit': sys.argv[2], 'godot': sys.argv[3], 'presets': sys.argv[4:],
    'runtime_sources_committed': True, 'source_snapshot': 'git archive',
}, indent=2) + '\n')
PY
echo "Builds in $OUT:"; ls -lh "$OUT"
