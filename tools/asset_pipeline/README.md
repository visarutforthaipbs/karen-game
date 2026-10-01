# Prop Asset Pipeline

Turns a concept image (or any existing model) into a game-ready low-poly prop that the game picks up automatically.
Characters have their own pipeline in `tools/character_pipeline/`. This one is for everything else in `ASSETS.md`.

```
concept image ──► TripoSR (gpu01) ──► Blender 4.5 headless cleanup (gpu01) ──► assets/props/<ID>_<name>_<variant>.glb
existing .glb/.obj/.fbx ─────────────┘                                          └► previews/<...>.png turntable + stats
                                                                                   └► Godot import + validation (Mac)
```

## Quick start

```bash
# 1. Get the concept-image prompt for an asset ID (IDs are in ASSETS.md)
./tools/asset_pipeline/build_asset.sh S1 --prompt

# 2. Generate that image with any image tool (white background, single object, front-right 3/4 view)

# 3. Build the prop (about 40 s)
./tools/asset_pipeline/build_asset.sh S1 --image path/to/hut.png

# More variants of the same prop are spread across cells in the game
./tools/asset_pipeline/build_asset.sh E3 --image brush1.png --variant a
./tools/asset_pipeline/build_asset.sh E3 --image brush2.png --variant b

# Already have a model (hand-made, TRELLIS, CC0 download)? Run it through the same cleanup:
./tools/asset_pipeline/build_asset.sh E2 --mesh bamboo_clump.glb
```

Then start a burn: the game uses `assets/props/*.glb` in place of the procedural mesh for that ID.
Delete the file to go back to the procedural version.

## What the cleanup does (`gpu/blender_cleanup.py`)

1. Empty scene, imports the mesh, removes helper objects, joins everything into one mesh.
2. Merges duplicate vertices, makes normals point outward (marching-cubes meshes can be inside-out), drops floating fragments.
3. Undoes the concept's camera angle (`--view`). **Hard-surface** props also get a few-degree auto-squaring so walls and buildings line up with the grid.
4. Collapse-decimates to the triangle budget. **Hard-surface** props also get a planar dissolve, so flat faces stay flat.
5. Colour: one flat colour per face (the faceted low-poly look). Colours are matched to the concept image, because TripoSR washes them out. Then a small saturation lift and a nudge toward the game palette (`palette.json`).
6. Scales to the spec size. Puts the origin at the base centre (y = 0), +Y up, front facing +Z. Exports a GLB with vertex colours.
7. Renders four Cycles turntable views (front, 3/4, right, back) into one preview sheet, and writes `stats.json`.

`validate_assets.py` then checks: triangle budget, fitted size (±3%), base at y = 0, centred, vertex colours present.

## Options

| Option | Meaning |
|---|---|
| `--variant a..z` | Variant letter (default `a`) |
| `--view front \| three-quarter-right \| three-quarter-left` | Camera angle of the concept image (default `three-quarter-right`). TripoSR treats whatever faces the camera as the front, so this undoes that turn |
| `--mesh-colors linear \| srgb` | Colour encoding of a `--mesh` file. `linear` is right for Blender and most downloads; use `srgb` for files exported by Godot or trimesh |
| `--skip-import` | Don't run the Godot import (do it later with `godot --headless --editor --quit`) |
| `--keep-remote` | Keep the gpu01 work folder (`~/asset_pipeline/work/...`) for debugging |

## Files

| File | Role |
|---|---|
| `asset_manifest.json` | Per-ID spec: name, route, category (organic/hard), fit axis and size in metres, triangle budget, variants, concept description |
| `palette.json` | Game colour palette (from `LowPoly.gd` / `FireGrid.gd`) |
| `gpu/prop_generate.py` | Stage 1 on gpu01: background removal + TripoSR + orientation to game space |
| `gpu/blender_cleanup.py` | Stage 2 on gpu01: everything in "What the cleanup does" above |
| `build_asset.sh` | Mac orchestrator: upload, run, download, import, validate |
| `validate_assets.py` | Standalone checker (`python3 validate_assets.py` checks every prop) |
| `scripts/AssetLibrary.gd` | Game side: finds `assets/props/<ID>_*.glb`, flattens each into one mesh, falls back to procedural |

## Notes and limits

- **Thin geometry** (route `proc`: pine, bamboo, grass, tool handles) comes out of TripoSR as blobs. Model those by hand or with a script, then use `--mesh`.
- **Orientation** was verified with an asymmetric test object: the concept's right side lands on +X and the side facing the camera on +Z. This is the same rotation as the character pipeline.
- **GPU sharing:** the script needs about 5 GB of free VRAM and refuses to start otherwise (TRELLIS / ollama jobs may be using the 3090).
- **Requirements on gpu01:** `~/aienv` (TripoSR, rembg, trimesh, PIL), `~/TripoSR`, and Blender 4.5 LTS at `~/apps/blender-4.5.14-linux-x64/`.
- Uses TripoSR (MIT). Hunyuan3D was deliberately not used (licence excludes the EU, UK and South Korea).
