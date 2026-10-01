# Character generation and quality checks

After visual review, follow [SOP](../../SOP.md) and the
[rigging guide](rigging_guide.md) for skeleton, skin and game integration.
`run_rig.py` now implements the calibrated Kha-nae rig; generation outputs alone
remain unrigged.

The legacy TripoSR route is a fast vertex-colour prototype generator. Its successful
mesh validation does **not** establish facial likeness or visual quality. The
textured TRELLIS.2 route is the candidate path for higher visual fidelity.

## One-command refined character build

The refined route automates the recipe that improved Kha-nae's surface and woven
clothing. Use one clear full-body character reference with visible face, hands,
feet and separated limbs. The reference should already express the desired 3D
proportions and materials; this command does not invent a better reference.

```bash
python3 tools/character_pipeline/run_refined_character.py \
  --image artifacts/character_expansion_20261001/references/khanae_3d_reference_v2.png \
  --name khanae --height 1.20
```

For another character, change `--image`, `--name`, and `--height`. The default
game budget is 40,000 triangles. This runs the original 1024 generation with a
saved material cache, closes and reconstructs its surface at 512, smooths and
reduces it, rebakes cached material, prepares the game mesh, and runs **fresh
texture inference** at 1024 / 2K, 24 steps, seed 42. Finally it restores height
and ground position (texture export resets these), validates the GLB and creates
a four-angle Godot preview. The final model lives in `candidate/`; intermediate
`retextured.glb` has not yet had its scale corrected.
The initial generation uses `--source-only`, so it does not attempt to decimate
the damaged original surface before the refinement has repaired it.

Reuse a completed source run without repeating shape generation:

```bash
python3 tools/character_pipeline/run_refined_character.py \
  --image artifacts/character_expansion_20261001/references/khanae_3d_reference_v2.png \
  --name khanae --height 1.20 \
  --from-run artifacts/character_expansion_20261001/khanae_recovered/run.json
```

The source cache must still exist on the chosen GPU host. The runner verifies
local and remote reference hashes, records cache and executable hashes, snapshots
the scripts, and logs each stage with its failure or completion. Results go into
a fresh folder under `artifacts/character_candidates`; choose an empty
`--output-dir` if needed. A failed run retains diagnostic outputs. Retrying with
`--from-run` starts a fresh refinement, not a partly overwritten candidate.

Both neural stages require at least 20,000 MiB free VRAM. Other GPU work is never
stopped automatically. The GPU needs `trellis-rebake-gltf`, `trellis2-texture-mesh`
and the shape encoder weights as well as the dependencies below. The local Mac
needs Godot for rendering; `--skip-preview` supports a host without a display.

Successful execution ends at **`awaiting_visual_review`**, never automatic
production installation. Validation checks finite geometry, triangle budget,
zero-area faces, UVs, embedded 2K textures, height and grounding. Compare
`reference.png` (or `.jpg`) with `preview.png` for facial likeness, fingers,
hat/hair silhouette, garment patterns and side/back defects. These meshes remain
unrigged. This is a tested Kha-nae recipe, not a guarantee that every character
will pass on its first generation. Surface closing can merge narrow gaps or
remove small features; likeness must be reviewed on each new character.

The original failure was not solved by a larger texture: the 4K cached bake
retained the weak embroidery. Rebuilding the surface improved geometry, and
regenerating texture on that repaired mesh improved pattern fidelity. The texture
trial changed seed and steps together, so their individual contribution is not
established.

The first automated cache-to-candidate validation completed in 292 seconds and
reproduced the clearer woven hat and tunic patterns, with 39,799 triangles and
six passing regression checks. Evidence is in
`artifacts/khanae_refined_pipeline_validation/REVIEW.md`. This measured run reused
the original shape cache; initial generation plus refinement has not yet been
rerun as one complete fresh GPU job.

## Basic candidate build (without refinement)

```bash
python3 tools/character_pipeline/run_character.py \
  --image assets/concept_art/tapoh_front_a_pose.jpg \
  --name tapoh --height 1.15 --backend trellis2 \
  --resolution 1024 --faces 12000
```

The runner uploads the input to `ssh gpu`, checks available VRAM, runs inference
and Blender preparation, and downloads into a unique `artifacts/character_candidates/`
directory. It never installs the result into `assets/models`. Use an empty
`--output-dir` to choose a destination. `run.json` records the input hash, parameters,
immutable source snapshots, script hashes, native runtime hashes, remote job directory, status and elapsed time; `run.log` keeps the
backend output. A failed preparation also downloads partial outputs for diagnosis.

Textured output includes a normalized detailed `*_master.glb`, a budgeted
`*_<budget>tris.glb`, and texture/mesh metrics.
The model is grounded at Y=0 with the requested height. These are **unrigged**
meshes. Procedural bobbing is not skeletal animation.

`--resolution 1024` is the quality default and needs at least 20,000 MiB free VRAM at preflight. `--resolution 512` uses the lower resolution model profile and checks for 12,000 MiB. These are preflight guards, not guaranteed peak-memory limits. `--steps` defaults to
12 and the reproducible seeds are 1/18. Larger settings are not a guarantee of
better output: inspect every candidate. Textured meshes default to 12,000
triangles; the old 2,500-triangle target can seriously damage facial and garment
details and can fail on intersecting neural geometry. Over-budget exports fail
explicitly. No silent budget relaxation occurs.

For the repaired fast route:

```bash
python3 tools/character_pipeline/run_character.py \
  --image assets/concept_art/munaw_front_a_pose.jpg \
  --name munaw --height 1.10 --backend triposr-v2 --faces 2500
```

V2 now preserves byte colour data, checks for blank/white output, and grades the
back after orienting the mesh. It can also reprocess a cached raw mesh with
`generate_character_v2.py --raw-mesh ...` on the GPU host.

## Remote dependencies

This runner targets the existing `gpu` machine and its installed paths:

- `~/aienv/bin/python3` with TripoSR, trimesh, scipy, numpy, Pillow, rembg and matplotlib.
- `~/apps/blender-4.5.14-linux-x64/blender`.
- `~/tools/trellis2.c/build-cuda/trellis2-image-to-gltf` and sibling `vkmesh`.
- Weights under `~/tools/TRELLIS.2/{TRELLIS.2-4B,dinov3-vitl16-pretrain-lvd1689m,BiRefNet}`.

The tested native implementation is `https://github.com/Wimacs/trellis2.c`, revision
`51b364e3a4dbc1ea076b186bcf86665f507bfde4`. It is a native port, not the official
Python runtime; output quality must be judged on this implementation's results.

Texture export requires a build with `TRELLIS2_C_ENABLE_GLTF_VULKAN_BAKE=ON`.
The pre-existing binary had this disabled. We rebuilt it with Vulkan headers and
`glslc` extracted from Ubuntu packages into a user-local SDK (no sudo). The SDK
used on this host is `~/character_benchmark_20261001/vulkan-sdk`:

```bash
cd ~/tools/trellis2.c
sdk="$HOME/character_benchmark_20261001/vulkan-sdk"
~/aienv/bin/cmake -S . -B build-cuda \
  -DTRELLIS2_C_ENABLE_GLTF_VULKAN_BAKE=ON \
  -DVulkan_INCLUDE_DIR="$sdk/usr/include" \
  -DVulkan_LIBRARY=/usr/lib/x86_64-linux-gnu/libvulkan.so.1 \
  -DVulkan_GLSLC_EXECUTABLE="$sdk/usr/bin/glslc"
LD_LIBRARY_PATH="$sdk/usr/lib/x86_64-linux-gnu:${LD_LIBRARY_PATH:-}" \
  ~/aienv/bin/cmake --build build-cuda -j4
```

The 3090's small host-visible BAR heap also caused topology cleanup to choose a
64 MiB workspace. The opt-in patch in `patches/vkmesh-small-bar.patch` selects
coherent host memory instead. Apply from the native repository root using
`patch -p1 < /path/to/vkmesh-small-bar.patch`, then rebuild `vkmesh`.
The runner enables it with `TRELLIS_VKMESH_HOST_MEMORY=1` and a 2048 MiB workspace
cap. This can trade speed for compatibility; it is not extra physical VRAM.
Original source/binaries were saved remotely in
`~/character_benchmark_20261001/runtime-backup/` before these changes.

## Inspect actual rendered surfaces

The game animator preserves imported base-colour texture materials. Legacy
vertex-colour meshes continue using the existing toon material.

Create a JSON array with one record per row:

```json
[
  {"label": "Current", "path": "/absolute/path/current.glb"},
  {"label": "Candidate", "path": "/absolute/path/candidate.glb", "vertex_material": false}
]
```

```bash
godot --path . --rendering-method gl_compatibility \
  --script tools/character_pipeline_v2/render_benchmark.gd -- \
  /absolute/path/manifest.json /absolute/path/comparison.png
```

This renders front (+Z), 45°, side and back with the same lighting and camera.
It captures an offscreen sheet, so window size does not crop the rows. Check face
readability, silhouette, garment pattern, tool separation, back/side consistency,
holes, texture seams and the loss from master to game mesh. A point-cloud preview
or triangle count alone is insufficient.

## Regression checks

Python integration tests need the GPU environment and `BLENDER_BIN`:

```bash
BLENDER_BIN=/path/to/blender python3 -m unittest discover \
  -s tools/character_pipeline_v2/tests -v
BLENDER_BIN=/path/to/blender python3 -m unittest discover \
  -s tools/character_pipeline/tests -v
godot --headless --path . --script tests/test_character_materials.gd
godot --headless --path . --script tests/test_all.gd
godot --headless --path . --fixed-fps 60 --quit-after 120
python3 tools/character_pipeline/validate_character_assets.py
```

Keep candidate masters and previews until visual review passes. Skinning,
animation deformation and equivalent Meshy GLB comparisons remain separate
acceptance checks. A Meshy screenshot establishes a visual target, not measured
parity in topology, rigging or runtime cost.

## Earlier baseline outcome

The 2026-10-01 run produced a visually improved Ta-poh master (97,192 triangles)
and a validated textured game candidate (11,940 triangles). Kha-nae's second
1024 run failed the 12,000-triangle budget and had visible surface noise. It is
rejected. The route still needs work on consistency; success for one character
does not establish Meshy parity. Evidence and known failures are in
`artifacts/character_benchmark_20261001/RESULTS.md`.


## Character expansion and recovery (2026-10-01)

Mu-naw now has a visually reviewed 39,779-triangle candidate and a 23,857-triangle
alternative, both with 2K textures and no zero-area faces. The 12K versions lost
facial/texture detail and were rejected. The reference-specific hair repair and
selected outputs are under `artifacts/character_expansion_20261001/deliverables`.
This repair is specific to the saved Mu-naw master; it is not an automatic rule
for other characters. Imported solid hair materials are now preserved in Godot.

`--faces` controls the requested game budget; the runner no longer adds a second,
implicit 12K export when a larger budget is requested. The standalone Blender
preparation script accepts multiple values after `--faces` for optional LODs.

`--remesh-resolution 512` changes the cleanup grid while keeping neural generation
at 1024. The first attempt for Kha-nae with an improved reference failed on the GPU
during texture generation. The later recovery and refinement are documented below.
`--save-material-cache` keeps intermediate geometry/material data in the remote
job's `material_cache` directory. Available files depend on how far the run gets.
Kha-nae's interrupted job only saved `raw.meshbin`. The subsequent completed
`khanae_trellis2_549e5b150c` run includes the full PBR cache used for refinement.

The runner rejects GPU health containing `N/A` or `ERR!` before inference. During
the Kha-nae attempt the kernel reported Xid 62 followed by Xid 154 and explicitly
requested a GPU reset. CUDA initialization then failed. The cause is undetermined;
no automatic machine reboot or driver reset was performed.

## Kha-nae recovered and installed, then visually rejected (2026-10-01)

After the user restarted the GPU, CUDA preflight and the full 1024 neural / 512
cleanup run passed. The selected Kha-nae model has 39,255 triangles, 2K textures,
no zero-area faces, and is installed in `KhanaeChibi.tscn`. It uses procedural
animation, with no skeleton. Full run evidence, master comparison, geometry
metrics and the cancelled optional 1024 cleanup experiment are in
`artifacts/character_expansion_20261001/khanae_recovered`; curated files and
in-game renders are in the adjacent `deliverables` directory. Hat, hand and
cloth detail still need polish.

## Experimental Kha-nae surface recovery

The previously installed Kha-nae is visually rejected despite its technical pass.
A controlled recovery from its cached PBR voxel coordinates produces a cleaner
face, hands, hat brim and clothing silhouette. This is an experimental candidate
route, not a default for all characters and not automatic visual acceptance.

On the GPU host, `rebuild_cached_surface.py pbr_voxels.bin closed.meshbin` uses
NumPy, SciPy and scikit-image to close the sparse surface at a 512-cell grid and
extract triangles. It currently accepts the tested 1024-resolution, single-batch,
six-channel PBR cache only. Then run Blender with
`-P decimate_cached_surface.py -- closed.meshbin reduced.meshbin` to smooth and
reduce it to 150K triangles without changing its native cache coordinates.
Use `trellis-rebake-gltf --mesh reduced.meshbin --voxels pbr_voxels.bin
--sample raw.meshbin --texture-size 2048 --gltf candidate.glb` to bake the saved
colours. Normalize and derive game budgets using `prepare_textured_character.py`.
Do not normalize the geometry before the cache-based bake.

The compared 4K bake did not materially restore missing embroidery. Texture
resolution is not a substitute for reference fidelity. The trials and acceptance
record are in `artifacts/khanae_quality_repair/`.

A subsequent texture-only pass **did** improve Kha-nae's hat weave and tunic
patterns: `trellis2-texture-mesh --model <TRELLIS.2-4B> --dino <DINOv3>
--input <rebuilt_game.glb> --image <reference.png> --image-prepared
--resolution 1024 --texture-size 2048 --steps 24 --seed 42
--shape-latent-output <shape.slat> --output <retextured.glb>`.
This export resets the scale/origin; run `prepare_textured_character.py` afterward
with height 1.20 and budget 40000. The selected result measures 39,799 triangles,
1.200000 m height, ground Y=0, no zero-area triangles, and 2K textures.
It remains a review candidate outside the game: face proportions, hands and rear
hair still differ from the reference. See `artifacts/khanae_quality_repair/candidate`,
`before_after.png`, and `acceptance.json` for the recipe, evidence and limitations.
