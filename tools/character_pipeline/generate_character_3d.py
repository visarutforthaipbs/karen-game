#!/usr/bin/env python3
"""
Under Two Skies - Local AI 3D Character Generation Pipeline
Automated end-to-end character generator for RTX 3090 GPU Node.

Pipeline:
1. Image Ingestion & Alpha Preprocessing (rembg + foreground centering)
2. Neural 3D Surface Reconstruction (TripoSR / RTX 3090)
3. High-res Marching Cubes Mesh Extraction
4. Quadric Decimation to Game-Ready Low Poly Budget (~2,000 - 3,000 faces, default 2,500)
5. 3D Nearest-Neighbor Vertex Color Transfer
6. Game Engine Coordinate Reorientation & Grounding (Y-Up, X-Right, -Z-Forward, Y=0 Ground)
7. Dual Export (.glb with vertex colors & .obj)
8. Automated 360 Turntable Preview Render (Front, 3/4, Profile, Back)

Artifacts written to --output-dir/<name>/:
  <name>_raw.glb        high-res marching-cubes mesh (debug)
  <name>_lowpoly.glb    game-ready mesh with COLOR_0 vertex colors
  <name>_lowpoly.obj    same mesh for DCC / auto-rigging tools
  <name>_turntable.png  4-angle turnaround preview sheet
"""

import os
import sys
import argparse
import time
from pathlib import Path
from PIL import Image
import numpy as np

# 3D & Numerical Libraries
import torch
import trimesh
import fast_simplification
from scipy.spatial import cKDTree
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

# TripoSR Module Setup
TRIPOSR_PATH = os.path.expanduser("~/TripoSR")
if TRIPOSR_PATH not in sys.path:
    sys.path.append(TRIPOSR_PATH)

from tsr.system import TSR
from tsr.utils import remove_background, resize_foreground
import rembg

def preprocess_concept_image(image_path: str, output_dir: str, foreground_ratio: float = 0.85) -> Image.Image:
    """Removes image background, centers the character, and composites against neutral background."""
    print(f"[1/7] Preprocessing concept image: {image_path}")
    session = rembg.new_session()
    raw_img = Image.open(image_path).convert("RGBA")
    
    img_no_bg = remove_background(raw_img, session)
    img_resized = resize_foreground(img_no_bg, foreground_ratio)
    
    # Composite onto neutral gray for TripoSR conditioning
    img_np = np.array(img_resized).astype(np.float32) / 255.0
    composite = img_np[:, :, :3] * img_np[:, :, 3:4] + (1.0 - img_np[:, :, 3:4]) * 0.5
    processed_img = Image.fromarray((composite * 255.0).astype(np.uint8))
    
    os.makedirs(output_dir, exist_ok=True)
    processed_img.save(os.path.join(output_dir, "input_preprocessed.png"))
    return processed_img

def reconstruct_neural_mesh(model: TSR, image: Image.Image, device: str = "cuda:0", mc_res: int = 256) -> trimesh.Trimesh:
    """Executes neural forward pass on RTX 3090 and extracts raw high-res surface."""
    print(f"[2/7] Running neural surface reconstruction on {device}...")
    t0 = time.time()
    with torch.no_grad():
        scene_codes = model([image], device=device)
    t_model = time.time() - t0
    print(f"      Neural inference completed in {t_model:.2f}s")
    
    print(f"[3/7] Marching cubes extraction at resolution {mc_res}^3...")
    t1 = time.time()
    meshes = model.extract_mesh(scene_codes, True, resolution=mc_res)
    raw_mesh = meshes[0]
    t_mc = time.time() - t1
    print(f"      Surface extracted: {len(raw_mesh.vertices)} vertices, {len(raw_mesh.faces)} faces ({t_mc:.2f}s)")
    return raw_mesh

def decimate_mesh(raw_mesh: trimesh.Trimesh, target_faces: int = 2500) -> trimesh.Trimesh:
    """Reduces polygon count to target budget while preserving crisp low-poly facets and vertex colors."""
    raw_faces = len(raw_mesh.faces)
    print(f"[4/7] Decimating mesh from {raw_faces} to ~{target_faces} faces...")

    if raw_faces <= target_faces:
        print(f"      Skipping decimation: already at or under target ({raw_faces} <= {target_faces})")
        return raw_mesh

    reduction_rate = 1.0 - (target_faces / raw_faces)

    simplified_v, simplified_f = fast_simplification.simplify(
        raw_mesh.vertices, raw_mesh.faces, target_reduction=reduction_rate
    )

    # 3D Nearest-Neighbor color transfer from high-res radiance field
    tree = cKDTree(raw_mesh.vertices)
    _, nearest_indices = tree.query(simplified_v)
    simplified_colors = raw_mesh.visual.vertex_colors[nearest_indices]

    decimated_mesh = trimesh.Trimesh(
        vertices=simplified_v,
        faces=simplified_f,
        vertex_colors=simplified_colors
    )
    # Drop zero-area triangles left behind by simplification
    decimated_mesh.update_faces(decimated_mesh.nondegenerate_faces())
    decimated_mesh.remove_unreferenced_vertices()
    print(f"      Optimized mesh: {len(decimated_mesh.vertices)} vertices, {len(decimated_mesh.faces)} faces")
    return decimated_mesh

def orient_and_ground(mesh: trimesh.Trimesh, target_height: float = 1.2) -> trimesh.Trimesh:
    """Transforms raw coordinates into standard game engine space (+Y Up, +X Right, -Z Forward, Y=0 Ground)."""
    print(f"[5/7] Aligning coordinates to Game Engine standard (Target Height: {target_height}m)...")
    v = mesh.vertices.copy()
    new_v = np.zeros_like(v)
    
    # TripoSR coordinates: v[:, 0] is Feet-to-Head, v[:, 1] is Left-to-Right, v[:, 2] is Front-to-Back
    new_v[:, 0] = v[:, 1]   # Godot X (Right)
    new_v[:, 1] = v[:, 0]   # Godot Y (Up)
    new_v[:, 2] = -v[:, 2]  # Godot Z (Forward/Back)
    
    # Ground feet plane to Y = 0.0
    new_v[:, 1] -= new_v[:, 1].min()
    
    # Center X and Z around origin
    new_v[:, 0] -= (new_v[:, 0].max() + new_v[:, 0].min()) * 0.5
    new_v[:, 2] -= (new_v[:, 2].max() + new_v[:, 2].min()) * 0.5
    
    # Normalize to specified chibi stature
    curr_height = new_v[:, 1].max()
    if curr_height > 0:
        scale_factor = target_height / curr_height
        new_v *= scale_factor
        
    return trimesh.Trimesh(
        vertices=new_v,
        faces=mesh.faces,
        vertex_colors=mesh.visual.vertex_colors
    )

def render_turntable_preview(mesh: trimesh.Trimesh, output_path: str, character_name: str) -> None:
    """Generates a 4-angle studio turnaround sheet (Front, 3/4, Profile, Back)."""
    print(f"[7/7] Rendering 4-angle turnaround preview: {output_path}")
    v = mesh.vertices.copy()
    c = mesh.visual.vertex_colors[:, :3] / 255.0

    angles = [0, 45, 90, 180]
    labels = ["Front (0°)", "3/4 Angle (45°)", "Side Profile (90°)", "Back (180°)"]

    # Frame the subject from its actual bounds so taller/shorter characters are not clipped
    half_w = max(abs(v[:, 0]).max(), abs(v[:, 2]).max()) * 1.15
    y_min = v[:, 1].min()
    y_max = v[:, 1].max()
    y_pad = max((y_max - y_min) * 0.08, 0.05)

    fig, axes = plt.subplots(1, 4, figsize=(16, 5))
    fig.suptitle(f"{character_name} - 3D Low Poly Chibi Asset", fontsize=15, fontweight="bold", color="white")

    for ax, ang, label in zip(axes, angles, labels):
        rad = np.radians(ang)
        cos_a, sin_a = np.cos(rad), np.sin(rad)

        x_rot = v[:, 0] * cos_a - v[:, 2] * sin_a
        z_rot = v[:, 0] * sin_a + v[:, 2] * cos_a
        y_pos = v[:, 1]

        # Painter depth sort
        depth_order = np.argsort(z_rot)
        ax.scatter(x_rot[depth_order], y_pos[depth_order], c=c[depth_order], s=5, edgecolors="none")
        ax.set_title(label, fontsize=12, color="#dddddd")
        ax.set_aspect("equal")
        ax.set_xlim(-half_w, half_w)
        ax.set_ylim(y_min - y_pad, y_max + y_pad)
        ax.axis("off")

    plt.tight_layout()
    plt.savefig(output_path, dpi=150, bbox_inches="tight", facecolor="#18181c")
    plt.close()

def main():
    parser = argparse.ArgumentParser(description="Under Two Skies 3D Character Generation Pipeline")
    parser.add_argument("--image", required=True, help="Path to input 2D orthographic A-pose concept image")
    parser.add_argument("--name", required=True, help="Character identifier (e.g., khanae, tapoh, munaw)")
    parser.add_argument("--faces", type=int, default=2500, help="Target face count for low poly decimation (default: 2500)")
    parser.add_argument("--height", type=float, default=1.2, help="Target character height in meters (default: 1.2)")
    parser.add_argument("--output-dir", default="output", help="Directory to save generated assets")
    parser.add_argument("--device", default="cuda:0", help="Compute device (default: cuda:0)")
    args = parser.parse_args()
    
    char_out_dir = os.path.join(args.output_dir, args.name)
    os.makedirs(char_out_dir, exist_ok=True)
    
    device = args.device if torch.cuda.is_available() else "cpu"
    print(f"=== Starting Character Pipeline for '{args.name}' on {device} ===")
    
    # 1. Preprocess
    img = preprocess_concept_image(args.image, char_out_dir)
    
    # 2. Model Initialization
    print("Loading TSR model weights...")
    model = TSR.from_pretrained("stabilityai/TripoSR", config_name="config.yaml", weight_name="model.ckpt")
    model.renderer.set_chunk_size(8192)
    model.to(device)
    
    # 3. Neural Reconstruction
    raw_mesh = reconstruct_neural_mesh(model, img, device=device)
    raw_mesh.export(os.path.join(char_out_dir, f"{args.name}_raw.glb"))
    
    # 4. Decimation + vertex color transfer
    decimated_mesh = decimate_mesh(raw_mesh, target_faces=args.faces)
    
    # 5. Coordinate Alignment & Grounding
    final_mesh = orient_and_ground(decimated_mesh, target_height=args.height)
    
    # 6. Exporting
    print("[6/7] Exporting GLB and OBJ...")
    glb_path = os.path.join(char_out_dir, f"{args.name}_lowpoly.glb")
    obj_path = os.path.join(char_out_dir, f"{args.name}_lowpoly.obj")
    final_mesh.export(glb_path)
    final_mesh.export(obj_path)
    print(f"Asset exported: {glb_path} ({len(final_mesh.vertices)} verts, {len(final_mesh.faces)} faces)")
    
    # 7. Turntable Preview
    preview_path = os.path.join(char_out_dir, f"{args.name}_turntable.png")
    render_turntable_preview(final_mesh, preview_path, args.name.capitalize())
    
    print(f"=== Pipeline completed successfully for '{args.name}' ===")

if __name__ == "__main__":
    main()
