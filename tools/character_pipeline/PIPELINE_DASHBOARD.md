# Character Pipeline Dashboard & Benchmarks

> 2026-10-01 audit: the registry below describes legacy prototype assets. “Production Ready” means the existing geometry checks passed, not visual approval. The measured quality work and new candidate runner are documented in [README.md](README.md). Historical timing claims below were not reproduced by the new end-to-end runner.

**Project:** Satellite Shadow (เงาเมฆา / ไร่หมุนเวียน)  
**Host:** `lighthouse-control` (macOS 15.x / Apple Silicon)  
**Compute Node:** `visarut298@lighthouse-gpu01` (`ssh gpu`)  
**Hardware:** NVIDIA GeForce RTX 3090 (24GB GDDR6X VRAM, Driver 595.84, CUDA 13.2)  
**Pipeline Script:** `tools/character_pipeline/generate_character_3d.py` (Local & Remote at `~/generate_character_3d.py`)  

---

## 1. Character Asset Registry

| Character | Concept Input | 3D Model (.glb) | 3D Model (.obj) | Triangles | Vertices | Height | Turnaround Sheet | Status |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Kha-nae (ขะแน)**<br>Rotational Farmer | `assets/concept_art/khanae_front_a_pose.jpg` | `assets/models/khanae_lowpoly.glb` (50 KB) | `assets/models/khanae_lowpoly.obj` (120 KB) | 2,498 | 1,253 | 1.20m | `assets/concept_art/khanae_turntable.png` | **Production Ready** |
| **Ta-poh (ตาโพ)**<br>Village Elder | `assets/concept_art/tapoh_front_a_pose.jpg` | `assets/models/tapoh_lowpoly.glb` (50 KB) | `assets/models/tapoh_lowpoly.obj` (120 KB) | 2,497 | 1,252 | 1.15m | `assets/concept_art/tapoh_turntable.png` | **Production Ready** |
| **Mu-naw (มูนอ)**<br>Agile Youth | `assets/concept_art/munaw_front_a_pose.jpg` | `assets/models/munaw_lowpoly.glb` (50 KB) | `assets/models/munaw_lowpoly.obj` (120 KB) | 2,498 | 1,249 | 1.10m | `assets/concept_art/munaw_turntable.png` | **Production Ready** |

---

## 2. RTX 3090 Performance Benchmarks

Measured on NVIDIA GeForce RTX 3090 24GB (`visarut298@lighthouse-gpu01`):

| Pipeline Stage | Tool / Kernel | Average Duration | VRAM Usage | Notes |
| :--- | :--- | :--- | :--- | :--- |
| **1. Background Removal** | `rembg` (U-2-Net ONNX) | 0.85s | ~800 MB | Alpha isolation + foreground centering |
| **2. Neural 3D Inference** | `TripoSR` (DINO ViT-B16 + NeRF) | **0.64s** | ~4.2 GB | Lightning-fast forward pass on 3090 |
| **3. Mesh Extraction** | `PyMCubes` (Resolution 256³) | 1.78s | ~1.8 GB | High-density raw surface (~85k - 100k tris) |
| **4. Low-Poly Decimation** | `fast_simplification` | 0.12s | ~200 MB | Reduces 100k -> 2,500 tris (QEM algorithm) |
| **5. Vertex Color Transfer** | `scipy.spatial.cKDTree` | 0.08s | ~150 MB | 3D Nearest-Neighbor color transfer |
| **6. Grounding & Export** | `trimesh` (GLB & OBJ) | 0.15s | ~100 MB | Bounds normalization, Y=0 feet alignment |
| **7. 360° Turntable Preview** | `matplotlib` Depth-Sort | 0.45s | ~200 MB | 4-angle studio turnaround render |
| **TOTAL RUNTIME** | **End-to-End** | **~4.07s** | **Peak: ~4.5 GB / 24 GB** | **Zero VRAM bottleneck** |

---

## 3. How to Generate a New Character / Variant

Preferred: run the workspace runner from the Mac (handles upload, execution, download, cleanup):

```bash
./tools/character_pipeline/generate_character.sh \
    assets/concept_art/new_character_front_a_pose.jpg \
    new_character \
    2500 \
    1.20
```

Or invoke the GPU node directly:

```bash
ssh gpu "~/aienv/bin/python3 ~/generate_character_3d.py \
    --image ~/pipeline_in_new_character.jpg \
    --name new_character \
    --faces 2500 \
    --height 1.20 \
    --output-dir ~/pipeline_out_new_character"
```

The script will automatically:
1. Strip the background and center the subject.
2. Reconstruct the 3D neural mesh on the RTX 3090 in ~0.64s.
3. Decimate the mesh to ~2,500 low-poly triangles (skipped if already at budget).
4. Transfer high-fidelity vertex colors and drop zero-area faces.
5. Re-orient to Game Engine space (+Y Up, Y=0 Ground).
6. Export `new_character_lowpoly.glb` and `new_character_lowpoly.obj`.
7. Generate `new_character_turntable.png` 4-angle turnaround sheet.

Validate the result against the registry:

```bash
python3 tools/character_pipeline/validate_character_assets.py
```
