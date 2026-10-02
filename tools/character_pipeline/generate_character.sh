#!/usr/bin/env bash
# ==============================================================================
# Under Two Skies — 3D Character Generation Pipeline Runner
# Host: Mac Workstation -> Compute: NVIDIA RTX 3090 (ssh gpu)
# ==============================================================================
set -euo pipefail

IMAGE_PATH="${1:-}"
CHAR_NAME="${2:-}"
TRIANGLES="${3:-2500}"
HEIGHT="${4:-1.20}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

if [[ -z "$IMAGE_PATH" || -z "$CHAR_NAME" ]]; then
    echo "Usage: $0 <image_path> <character_name> [triangles=2500] [height=1.20]"
    echo "Example: $0 assets/concept_art/khanae_front_a_pose.jpg khanae 2500 1.20"
    exit 1
fi

if [[ ! -f "$IMAGE_PATH" ]]; then
    echo "Error: Concept image not found at '$IMAGE_PATH'"
    exit 1
fi

# Keep names shell-safe: they are interpolated into ssh/scp remote commands.
if [[ ! "$CHAR_NAME" =~ ^[A-Za-z0-9][A-Za-z0-9_-]*$ ]]; then
    echo "Error: character name must be alphanumeric (plus _ or -), got '$CHAR_NAME'"
    exit 1
fi

if [[ ! "$TRIANGLES" =~ ^[0-9]+$ ]]; then
    echo "Error: triangles must be a positive integer, got '$TRIANGLES'"
    exit 1
fi

if [[ ! "$HEIGHT" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
    echo "Error: height must be a positive number, got '$HEIGHT'"
    exit 1
fi

echo "======================================================================"
echo " [1/5] Checking GPU Node Connection (ssh gpu)..."
echo "======================================================================"
ssh gpu "nvidia-smi --query-gpu=name,memory.total,memory.free --format=csv,noheader" || {
    echo "Error: Failed to reach GPU node via ssh gpu"
    exit 1
}

REMOTE_INPUT="pipeline_in_${CHAR_NAME}.jpg"
REMOTE_OUT_DIR="pipeline_out_${CHAR_NAME}"
# generate_character_3d.py writes to <output-dir>/<name>/ (see char_out_dir in main)
REMOTE_ARTIFACT_DIR="${REMOTE_OUT_DIR}/${CHAR_NAME}"

echo "======================================================================"
echo " [2/5] Uploading Concept Art & Synchronizing Pipeline Script..."
echo "======================================================================"
scp "$IMAGE_PATH" "gpu:~/${REMOTE_INPUT}"
scp "$SCRIPT_DIR/generate_character_3d.py" "gpu:~/generate_character_3d.py"

echo "======================================================================"
echo " [3/5] Executing 3D Neural Reconstruction & Low-Poly Decimation on RTX 3090..."
echo "======================================================================"
START_TIME=$(date +%s)
ssh gpu "~/aienv/bin/python3 ~/generate_character_3d.py \
    --image ~/${REMOTE_INPUT} \
    --name ${CHAR_NAME} \
    --faces ${TRIANGLES} \
    --height ${HEIGHT} \
    --output-dir ~/${REMOTE_OUT_DIR}"
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

echo "======================================================================"
echo " [4/5] Downloading Assets to Workspace..."
echo "======================================================================"
mkdir -p "$WORKSPACE_ROOT/assets/models"
mkdir -p "$WORKSPACE_ROOT/assets/concept_art"

scp "gpu:~/${REMOTE_ARTIFACT_DIR}/${CHAR_NAME}_lowpoly.glb" "$WORKSPACE_ROOT/assets/models/${CHAR_NAME}_lowpoly.glb"
scp "gpu:~/${REMOTE_ARTIFACT_DIR}/${CHAR_NAME}_lowpoly.obj" "$WORKSPACE_ROOT/assets/models/${CHAR_NAME}_lowpoly.obj"
scp "gpu:~/${REMOTE_ARTIFACT_DIR}/${CHAR_NAME}_turntable.png" "$WORKSPACE_ROOT/assets/concept_art/${CHAR_NAME}_turntable.png"

# Clean up remote temporary input and output directory
ssh gpu "rm -f ~/${REMOTE_INPUT} && rm -rf ~/${REMOTE_OUT_DIR}"

echo "======================================================================"
echo " [5/5] Generation Complete in ${DURATION}s!"
echo "======================================================================"
echo " Assets generated:"
echo "  - 3D Model (GLB): $WORKSPACE_ROOT/assets/models/${CHAR_NAME}_lowpoly.glb"
echo "  - 3D Model (OBJ): $WORKSPACE_ROOT/assets/models/${CHAR_NAME}_lowpoly.obj"
echo "  - Turntable:      $WORKSPACE_ROOT/assets/concept_art/${CHAR_NAME}_turntable.png"
echo "======================================================================"
