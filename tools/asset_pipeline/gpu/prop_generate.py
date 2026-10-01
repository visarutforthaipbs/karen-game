"""Satellite Shadow prop pipeline, stage 1 (runs on gpu01 with ~/aienv/bin/python3).

Concept image -> background removal -> TripoSR -> high-resolution vertex-coloured mesh,
re-oriented to glTF/Godot space (+Y up, front facing +Z, 1 unit = 1 m) and grounded at y = 0.
All decimation / styling / sizing happens later in Blender (blender_cleanup.py).

Usage:
  ~/aienv/bin/python3 prop_generate.py --image in.png --out raw.glb [--mc-res 256] [--foreground 0.85]
"""
import argparse
import os
import sys
import time

import numpy as np
import torch
import trimesh
from PIL import Image

sys.path.append(os.path.expanduser("~/TripoSR"))
from tsr.system import TSR  # noqa: E402
from tsr.utils import remove_background, resize_foreground  # noqa: E402
import rembg  # noqa: E402


def preprocess(image_path: str, foreground: float, debug_path: str, rgba_path: str) -> Image.Image:
    raw = Image.open(image_path).convert("RGBA")
    no_bg = remove_background(raw, rembg.new_session())
    centered = resize_foreground(no_bg, foreground)
    centered.save(rgba_path)  # colour reference for blender_cleanup (TripoSR washes colours out)
    arr = np.asarray(centered).astype(np.float32) / 255.0
    # TripoSR expects the object on neutral grey
    rgb = arr[:, :, :3] * arr[:, :, 3:4] + (1.0 - arr[:, :, 3:4]) * 0.5
    img = Image.fromarray((rgb * 255.0).astype(np.uint8))
    img.save(debug_path)
    return img


def to_game_space(mesh: trimesh.Trimesh) -> trimesh.Trimesh:
    """TripoSR axes: v0 = up, v1 = image left->right, v2 = away from the camera.
    Verified with an asymmetric probe (red pillar on the right end, step on the front):
    X = v1, Y = v0, Z = -v2 puts the image's right side on +X and the side facing the
    camera on +Z, i.e. the glTF / ASSETS.md convention (same rotation as the character pipeline)."""
    v = np.asarray(mesh.vertices)
    out = np.empty_like(v)
    out[:, 0] = v[:, 1]   # X (right)
    out[:, 1] = v[:, 0]   # Y (up)
    out[:, 2] = -v[:, 2]  # Z (front, toward the concept camera)
    out[:, 1] -= out[:, 1].min()
    out[:, 0] -= (out[:, 0].max() + out[:, 0].min()) * 0.5
    out[:, 2] -= (out[:, 2].max() + out[:, 2].min()) * 0.5
    return trimesh.Trimesh(vertices=out, faces=mesh.faces, vertex_colors=mesh.visual.vertex_colors, process=False)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--image", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--mc-res", type=int, default=256)
    ap.add_argument("--foreground", type=float, default=0.85)
    args = ap.parse_args()

    t0 = time.time()
    device = "cuda:0" if torch.cuda.is_available() else "cpu"
    model = TSR.from_pretrained("stabilityai/TripoSR", config_name="config.yaml", weight_name="model.ckpt")
    model.renderer.set_chunk_size(8192)
    model.to(device)

    out_dir = os.path.dirname(os.path.abspath(args.out))
    img = preprocess(args.image, args.foreground, os.path.join(out_dir, "input_processed.png"),
                     os.path.join(out_dir, "input_rgba.png"))
    with torch.no_grad():
        codes = model([img], device=device)
    mesh = model.extract_mesh(codes, True, resolution=args.mc_res)[0]
    mesh = to_game_space(mesh)
    mesh.export(args.out)
    print(f"[prop_generate] {len(mesh.faces)} faces -> {args.out} in {time.time() - t0:.1f}s")


if __name__ == "__main__":
    main()
