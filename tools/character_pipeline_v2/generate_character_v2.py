import os
import sys
import argparse
import time
import json
import subprocess
from pathlib import Path
import numpy as np
from PIL import Image, ImageEnhance
import trimesh
from scipy.spatial import cKDTree
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.collections import PolyCollection


def enhance_concept_colors(image: Image.Image) -> Image.Image:
    """Pre-processes concept art to prevent muddy AI vertex color wash-out."""
    # Boost color saturation and contrast slightly so NeRF learns vibrant highland dyes
    enhancer_color = ImageEnhance.Color(image)
    boosted = enhancer_color.enhance(1.25)
    enhancer_contrast = ImageEnhance.Contrast(boosted)
    boosted = enhancer_contrast.enhance(1.10)
    return boosted

def orient_and_ground(mesh: trimesh.Trimesh, target_height: float = 1.2) -> trimesh.Trimesh:
    v = mesh.vertices.copy()
    new_v = np.zeros_like(v)
    # TripoSR coordinates:
    # v[:, 0]: Feet-to-Head -> Godot Y
    # v[:, 1]: Left-to-Right -> Godot X
    # Preserve the tested TripoSR rotation; these character inputs face game +Z.
    new_v[:, 0] = v[:, 1]
    new_v[:, 1] = v[:, 0]
    new_v[:, 2] = -v[:, 2]

    # Ground feet plane to Y = 0.0
    new_v[:, 1] -= new_v[:, 1].min()

    # Center X and Z around origin
    new_v[:, 0] -= (new_v[:, 0].max() + new_v[:, 0].min()) * 0.5
    new_v[:, 2] -= (new_v[:, 2].max() + new_v[:, 2].min()) * 0.5

    # Scale to specified height
    curr_h = new_v[:, 1].max()
    if curr_h > 0:
        new_v *= (target_height / curr_h)

    return trimesh.Trimesh(
        vertices=new_v,
        faces=mesh.faces,
        vertex_colors=mesh.visual.vertex_colors
    )

def color_grade_vertices(mesh: trimesh.Trimesh) -> trimesh.Trimesh:
    """Brightens backside darkness and enhances saturation in vertex colors."""
    # trimesh treats float colours as 0..1; preserve uint8 for 0..255 data.
    colors = mesh.visual.vertex_colors.copy().astype(np.uint8)
    rgb = colors[:, :3].astype(np.float32) / 255.0

    # Backside illumination compensation (vertices facing backward along -Z)
    normals = mesh.vertex_normals
    back_facing = np.maximum(0.0, -normals[:, 2]) # Characters face +Z in the tested game assets
    
    # Restrained lift on the back; avoid bleaching faces and dark cloth.
    rgb += back_facing[:, None] * 0.06 * (1.0 - rgb)
    
    # Global gamma/vibrancy boost
    rgb = np.power(np.clip(rgb, 0.0, 1.0), 0.96)
    
    # Saturation boost in RGB
    mean_gray = rgb.mean(axis=1, keepdims=True)
    rgb = mean_gray + (rgb - mean_gray) * 1.08
    rgb = np.clip(rgb, 0.0, 1.0)

    colors[:, :3] = (rgb * 255.0).astype(np.uint8)
    mesh.visual.vertex_colors = colors
    return mesh

def render_comparison_sheet(mesh_v1: trimesh.Trimesh, mesh_v2: trimesh.Trimesh, output_path: str, char_name: str):
    """Renders side-by-side comparison between Workflow 1 and Workflow 2."""
    fig, axes = plt.subplots(2, 4, figsize=(18, 9))
    fig.patch.set_facecolor('#111116')

    angles = [0, 45, 90, 180]
    col_labels = ["Front (0°)", "3/4 Angle (45°)", "Side Profile (90°)", "Back (180°)"]
    
    workflows = [
        ("Workflow 1: Baseline (TripoSR + Fast Simplification)", mesh_v1),
        ("Workflow 2: Modern (Color Grade + Blender Headless Clean)", mesh_v2)
    ]

    for row_idx, (wf_label, m) in enumerate(workflows):
        v = m.vertices.copy()
        c = m.visual.vertex_colors[:, :3] / 255.0

        for col_idx, (ang, label) in enumerate(zip(angles, col_labels)):
            ax = axes[row_idx, col_idx]
            rad = np.radians(ang)
            cos_a, sin_a = np.cos(rad), np.sin(rad)

            x_rot = v[:, 0] * cos_a - v[:, 2] * sin_a
            z_rot = v[:, 0] * sin_a + v[:, 2] * cos_a
            y_pos = v[:, 1]

            depth_order = np.argsort(z_rot)
            ax.scatter(x_rot[depth_order], y_pos[depth_order], c=c[depth_order], s=6, edgecolors="none")
            ax.set_aspect("equal")
            ax.set_xlim(-0.85, 0.85)
            ax.set_ylim(-0.05, 1.35)
            ax.axis("off")

            if row_idx == 0:
                ax.set_title(label, fontsize=13, color="#dddddd", pad=10)
        
        # Row header
        axes[row_idx, 0].text(-0.8, 1.38, wf_label, fontsize=12, fontweight="bold", 
                              color="#64D2FF" if row_idx == 1 else "#FF9F0A")

    plt.suptitle(f"Character Pipeline Comparison: {char_name.capitalize()}", 
                 fontsize=16, fontweight="bold", color="white", y=0.98)
    plt.tight_layout()
    plt.savefig(output_path, dpi=160, bbox_inches="tight", facecolor="#111116")
    plt.close()
    print(f"Comparison sheet saved: {output_path}")

def run_pipeline_v2(image_path: str, char_name: str, target_faces: int = 2500, target_height: float = 1.20, out_dir: str = "output_v2", blender: str = "blender", raw_mesh_path: str = "", baseline: str = ""):
    import torch
    sys.path.insert(0, os.path.expanduser(os.environ.get("TRIPOSR_PATH", "~/TripoSR")))
    from tsr.system import TSR
    from tsr.utils import remove_background, resize_foreground
    import rembg

    if target_faces < 4 or target_height <= 0:
        raise ValueError("faces must be >= 4 and height must be positive")
    if not char_name or any(c not in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-" for c in char_name):
        raise ValueError("name must contain only letters, digits, underscore or hyphen")
    started = time.perf_counter()
    out_dir = str(Path(out_dir).resolve())
    device = "cuda:0" if torch.cuda.is_available() else "cpu"
    os.makedirs(out_dir, exist_ok=True)
    print(f"=== Running Workflow 2 for '{char_name}' on {device} ===")

    if raw_mesh_path:
        raw_mesh = trimesh.load(raw_mesh_path, force="mesh")
        raw_path = str(Path(raw_mesh_path).resolve())
    else:
        # 1. Load and enhance concept image
        print("[1/5] Removing background & color-enhancing concept art...")
        raw_img = Image.open(image_path).convert("RGBA")
        session = rembg.new_session()
        no_bg = remove_background(raw_img, session)
        resized = resize_foreground(no_bg, 0.85)
        
        # Composite over neutral background
        arr = np.array(resized).astype(np.float32) / 255.0
        comp = arr[:, :, :3] * arr[:, :, 3:4] + (1 - arr[:, :, 3:4]) * 0.5
        comp_img = Image.fromarray((comp * 255.0).astype(np.uint8))
        enhanced_img = enhance_concept_colors(comp_img)
        enhanced_img.save(os.path.join(out_dir, "input_enhanced.png"))
    
        # 2. Neural 3D Reconstruction
        print("[2/5] Running Neural 3D Reconstruction...")
        model = TSR.from_pretrained('stabilityai/TripoSR', config_name='config.yaml', weight_name='model.ckpt')
        model.renderer.set_chunk_size(8192)
        model.to(device)
        
        with torch.no_grad():
            scene_codes = model([enhanced_img], device=device)
        
        print("[3/5] Extracting high-density raw mesh (Marching Cubes 256³)...")
        meshes = model.extract_mesh(scene_codes, True, resolution=256)
        raw_mesh = meshes[0]
        del model, scene_codes
        if torch.cuda.is_available():
            torch.cuda.empty_cache()
        print(f"Raw Mesh: {len(raw_mesh.vertices)} vertices, {len(raw_mesh.faces)} faces")
    
        # Save temporary raw high-poly mesh for Blender
        raw_path = os.path.join(out_dir, f"{char_name}_raw_highpoly.glb")
        raw_mesh.export(raw_path)
    
    # 3. Blender Headless Decimation & Cleanup
    print("[4/5] Executing Blender cleanup and budgeted decimation...")
    blender_out_glb = os.path.join(out_dir, f"{char_name}_v2_decimated.glb")
    blender_script = str(Path(__file__).with_name("process_mesh.py"))
    ratio = min(1.0, float(target_faces) / float(len(raw_mesh.faces)))
    # Argument lists preserve paths safely and a failed Blender run stops the pipeline.
    subprocess.run([blender, "-b", "--python-exit-code", "1", "-P", blender_script, "--",
                    raw_path, blender_out_glb, str(ratio), str(target_faces)], check=True)
    decimated_mesh = trimesh.load(blender_out_glb, force="mesh")

    # Transfer color from raw high-poly mesh to decimated mesh
    tree = cKDTree(raw_mesh.vertices)
    _, idxs = tree.query(decimated_mesh.vertices)
    decimated_mesh.visual.vertex_colors = raw_mesh.visual.vertex_colors[idxs]

    # 4. Color Grading & Grounding
    print("[5/5] Color grading vertex colors & grounding mesh...")
    final_mesh_v2 = orient_and_ground(decimated_mesh, target_height=target_height)
    final_mesh_v2 = color_grade_vertices(final_mesh_v2)

    metrics = mesh_metrics(final_mesh_v2)
    metrics["elapsed_seconds"] = round(time.perf_counter() - started, 3)
    metrics["reused_raw_mesh"] = bool(raw_mesh_path)
    with open(os.path.join(out_dir, f"{char_name}_metrics.json"), "w") as f:
        json.dump(metrics, f, indent=2)
    if metrics["white_fraction"] > 0.98 or metrics["unique_rgb"] < 8:
        raise RuntimeError("Colour validation failed: output is effectively a single colour")
    if metrics["faces"] > target_faces:
        raise RuntimeError("Triangle budget exceeded")
    # Final export
    final_glb = os.path.join(out_dir, f"{char_name}_v2_lowpoly.glb")
    final_obj = os.path.join(out_dir, f"{char_name}_v2_lowpoly.obj")
    final_mesh_v2.export(final_glb)
    final_mesh_v2.export(final_obj)
    print(f"Exported Workflow 2 GLB: {final_glb}")


    if baseline:
        m_v1 = trimesh.load(baseline, force="mesh")
        comp_sheet = os.path.join(out_dir, f"{char_name}_pipeline_comparison.png")
        render_comparison_sheet(m_v1, final_mesh_v2, comp_sheet, char_name)

def mesh_metrics(mesh):
    rgb = mesh.visual.vertex_colors[:, :3]
    return {"faces": len(mesh.faces), "vertices": len(mesh.vertices),
            "height": float(mesh.extents[1]), "ground_y": float(mesh.bounds[0, 1]),
            "rgb_mean": rgb.mean(axis=0).tolist(),
            "white_fraction": float(np.all(rgb >= 245, axis=1).mean()),
            "unique_rgb": int(len(np.unique(rgb, axis=0))),
            "degenerate_faces": int((mesh.area_faces < 1e-12).sum())}

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument("--image", default="")
    parser.add_argument("--raw-mesh", default="", help="Reuse a raw TripoSR mesh to test cleanup without inference")
    parser.add_argument("--baseline", default="", help="Baseline GLB for surface comparison")
    parser.add_argument("--blender", default=os.environ.get("BLENDER_BIN", "blender"))
    parser.add_argument("--name", required=True)
    parser.add_argument("--faces", type=int, default=2500)
    parser.add_argument("--height", type=float, default=1.20)
    parser.add_argument("--output-dir", default="output_v2")
    args = parser.parse_args()

    if not args.image and not args.raw_mesh:
        parser.error("provide --image or --raw-mesh")
    run_pipeline_v2(args.image, args.name, args.faces, args.height, args.output_dir, args.blender, args.raw_mesh, args.baseline)
