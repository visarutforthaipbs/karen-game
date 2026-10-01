#!/usr/bin/env bash
# ==============================================================================
# Satellite Shadow — Prop Asset Pipeline (Mac -> gpu01 RTX 3090 -> Mac)
#
#   ./tools/asset_pipeline/build_asset.sh <ID> --prompt
#       Print the concept-image prompt for this asset (generate the image with any tool).
#   ./tools/asset_pipeline/build_asset.sh <ID> --image <concept.png> [--variant a]
#       Concept image -> TripoSR -> Blender cleanup -> assets/props/<ID>_<name>_<variant>.glb
#   ./tools/asset_pipeline/build_asset.sh <ID> --mesh <model.glb|.obj|.fbx> [--variant a]
#       Skip generation: run any existing mesh (hand-made, TRELLIS, CC0 download...) through
#       the same cleanup so it matches the game's style, size and orientation.
#
# Options: --view front|three-quarter-right|three-quarter-left (camera angle of the concept
#            image; default three-quarter-right, matching the manifest prompt)
#          --mesh-colors linear|srgb (colour encoding of a --mesh file: linear for Blender / most
#            downloads [default], srgb for files exported by Godot or trimesh)
#          --skip-import (don't run the Godot import), --keep-remote (keep gpu01 work dir)
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
MANIFEST="$SCRIPT_DIR/asset_manifest.json"
BLENDER="~/apps/blender-4.5.14-linux-x64/blender"
PY="~/aienv/bin/python3"
REMOTE_BASE="asset_pipeline"
MIN_FREE_VRAM_MB=5000

ID="${1:-}"; shift || true
IMAGE=""; MESH=""; VARIANT="a"; PROMPT_ONLY=0; SKIP_IMPORT=0; KEEP_REMOTE=0; VIEW="three-quarter-right"; MESH_COLORS="linear"
while [[ $# -gt 0 ]]; do
    case "$1" in
        --image) IMAGE="$2"; shift 2 ;;
        --mesh) MESH="$2"; shift 2 ;;
        --variant) VARIANT="$2"; shift 2 ;;
        --view) VIEW="$2"; shift 2 ;;
        --mesh-colors) MESH_COLORS="$2"; shift 2 ;;
        --prompt) PROMPT_ONLY=1; shift ;;
        --skip-import) SKIP_IMPORT=1; shift ;;
        --keep-remote) KEEP_REMOTE=1; shift ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

if [[ ! "$ID" =~ ^[A-Z][0-9]+$ ]]; then
    echo "Usage: $0 <ID> (--prompt | --image <png> | --mesh <glb>) [--variant a]"
    echo "IDs are listed in ASSETS.md / asset_manifest.json (e.g. S1, E3, V1)."
    exit 1
fi
if [[ ! "$VARIANT" =~ ^[a-z]$ ]]; then
    echo "Error: --variant must be a single letter a-z"; exit 1
fi
# TripoSR treats whatever faces the concept camera as the front: undo the 3/4 turn
case "$VIEW" in
    front) YAW=0 ;;
    three-quarter-right) YAW=45 ;;
    three-quarter-left) YAW=-45 ;;
    *) echo "Error: --view must be front, three-quarter-right or three-quarter-left"; exit 1 ;;
esac

# Manifest lookup (name, route, category, fit, meters, tris, desc)
SPEC="$(python3 - "$MANIFEST" "$ID" <<'EOF'
import json, sys
m = json.load(open(sys.argv[1]))
a = m["assets"].get(sys.argv[2])
if not a:
    sys.exit(f"Unknown asset ID {sys.argv[2]}")
prompt = m["style_prompt"].replace("{desc}", a["desc"])
print("\t".join([a["name"], a["route"], a["category"], a["fit"], str(a["meters"]), str(a["tris"]), prompt]))
EOF
)"
IFS=$'\t' read -r NAME ROUTE CATEGORY FIT METERS TRIS PROMPT <<< "$SPEC"
OUT_BASE="${ID}_${NAME}_${VARIANT}"

if [[ $PROMPT_ONLY -eq 1 ]]; then
    echo "$ID ($NAME) — route: $ROUTE, ${TRIS} tris, ${FIT} ${METERS} m"
    [[ "$ROUTE" == "proc" ]] && echo "Note: thin geometry; image-to-3D usually fails here. Prefer --mesh with a hand-made model."
    echo
    echo "$PROMPT"
    exit 0
fi

if [[ -n "$IMAGE" && -n "$MESH" ]] || [[ -z "$IMAGE" && -z "$MESH" ]]; then
    echo "Error: give exactly one of --image or --mesh"; exit 1
fi
INPUT="${IMAGE:-$MESH}"
[[ -f "$INPUT" ]] || { echo "Error: input not found: $INPUT"; exit 1; }
if [[ -n "$IMAGE" && "$ROUTE" == "proc" ]]; then
    echo "Warning: $ID is a 'proc' asset (thin geometry). TripoSR will likely produce a blob; continuing anyway."
fi

STAMP="$(date +%Y%m%d_%H%M%S)"
WORK="$REMOTE_BASE/work/${OUT_BASE}_${STAMP}"
INPUT_EXT="${INPUT##*.}"

echo "== [1/6] gpu01 preflight"
ssh gpu "test -x $BLENDER" || { echo "Error: Blender missing on gpu01 ($BLENDER)"; exit 1; }
if [[ -n "$IMAGE" ]]; then
    FREE=$(ssh gpu "nvidia-smi --query-gpu=memory.free --format=csv,noheader,nounits" | head -1 | tr -d ' ')
    echo "   free VRAM: ${FREE} MiB"
    if (( FREE < MIN_FREE_VRAM_MB )); then
        echo "Error: need ${MIN_FREE_VRAM_MB} MiB free VRAM for TripoSR (another job is using the GPU). Try again later."
        exit 1
    fi
fi

echo "== [2/6] upload scripts + input"
ssh gpu "mkdir -p ~/$WORK"
scp -q "$SCRIPT_DIR/gpu/prop_generate.py" "$SCRIPT_DIR/gpu/blender_cleanup.py" "$SCRIPT_DIR/palette.json" "gpu:~/$REMOTE_BASE/"
scp -q "$INPUT" "gpu:~/$WORK/input.$INPUT_EXT"

if [[ -n "$IMAGE" ]]; then
    echo "== [3/6] TripoSR image -> raw mesh"
    ssh gpu "cd ~/$WORK && $PY ~/$REMOTE_BASE/prop_generate.py --image input.$INPUT_EXT --out raw.glb"
    RAW="raw.glb"
    COLOR_ARGS="--ref-image input_rgba.png --yaw $YAW --input-colors srgb"
else
    echo "== [3/6] using supplied mesh (no generation)"
    RAW="input.$INPUT_EXT"
    [[ "$MESH_COLORS" =~ ^(linear|srgb)$ ]] || { echo "Error: --mesh-colors must be linear or srgb"; exit 1; }
    COLOR_ARGS="--input-colors $MESH_COLORS"
fi
[[ "$CATEGORY" == "hard" ]] && COLOR_ARGS="$COLOR_ARGS --auto-square"

echo "== [4/6] Blender cleanup ($CATEGORY, ${TRIS} tris, ${FIT} ${METERS} m)"
ssh gpu "cd ~/$WORK && $BLENDER -b --factory-startup --python ~/$REMOTE_BASE/blender_cleanup.py -- \
    --in $RAW --out final.glb --tris $TRIS --category $CATEGORY --fit $FIT --meters $METERS \
    --palette ~/$REMOTE_BASE/palette.json --stats stats.json --views views $COLOR_ARGS 2>&1 | grep -E '^\[blender_cleanup\]|Error|Traceback' || true"
ssh gpu "test -f ~/$WORK/final.glb" || { echo "Error: Blender cleanup failed (run with --keep-remote and inspect ~/$WORK)"; exit 1; }
ssh gpu "cd ~/$WORK && $PY - <<'EOF'
from PIL import Image
import glob
views = [Image.open(p).convert('RGB') for p in sorted(glob.glob('views/*.png'))]
w, h = views[0].size
sheet = Image.new('RGB', (w * len(views), h), (210, 210, 214))
for i, v in enumerate(views):
    sheet.paste(v, (i * w, 0))
sheet.save('turntable.png')
EOF"

echo "== [5/6] download"
mkdir -p "$ROOT/assets/props/previews"
scp -q "gpu:~/$WORK/final.glb" "$ROOT/assets/props/$OUT_BASE.glb"
scp -q "gpu:~/$WORK/turntable.png" "$ROOT/assets/props/previews/$OUT_BASE.png"
scp -q "gpu:~/$WORK/stats.json" "$ROOT/assets/props/previews/$OUT_BASE.json"
[[ -n "$IMAGE" ]] && scp -q "gpu:~/$WORK/input_processed.png" "$ROOT/assets/props/previews/${OUT_BASE}_input.png" || true
[[ $KEEP_REMOTE -eq 1 ]] || ssh gpu "rm -rf ~/$WORK"

echo "== [6/6] Godot import + validation"
if [[ $SKIP_IMPORT -eq 0 ]]; then
    godot --headless --editor --quit --path "$ROOT" >/dev/null 2>&1 || echo "Warning: Godot import returned an error; open the editor to re-import."
fi
python3 "$SCRIPT_DIR/validate_assets.py" "$ROOT/assets/props/$OUT_BASE.glb"

echo
echo "Done: assets/props/$OUT_BASE.glb  (preview: assets/props/previews/$OUT_BASE.png)"
echo "The game picks it up automatically the next time a burn starts."
