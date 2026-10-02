# Prop asset pipeline v2

Builds **review candidates** from images or self-contained static GLBs. The
character pipeline's useful lessons are applied here: prepared references,
repeatable inference settings, preserved materials, strict geometry validation,
four-angle renders and installation only after visual review.

## Required art direction

**Every route produces stylized low-poly game assets**, including the quality
route. Follow PRD §9.1: simple angular silhouettes, visible flat-shaded facets,
broad colour areas, the game's natural palette and restrained painted textures.
Keep important cultural and structural details in simplified form. Reject
photorealism, dense wood/thatch/fabric microtexture, noisy normal maps and glossy
realistic materials. Preserving a source texture does not automatically make it
appropriate for the game.

Quality means clearer shapes, better proportions and reference fidelity within
this style. Triangle budgets are ceilings, not detail targets. Before installing,
compare all four views and a gameplay-distance view with the existing game scene.
Reject a stylistic mismatch even if geometry validation passes; the validator
does not measure art style.

## Two routes

| Route | Intended assets | Geometry/material policy |
|---|---|---|
| Standard | Heavily instanced vegetation and simple props | Existing small budgets; vegetation uses one vertex-colour surface |
| Quality | Huts, barrels, prominent structures, surveillance bodies and tank | Explicit per-ID quality budget; UV textures and solid materials preserved |

Quality image builds use the installed native TRELLIS.2 runtime. Standard image
builds use TripoSR. Thin `proc` assets (bamboo culms, grass, tool handles) require
`--mesh`; the builder refuses image generation for them. Model their structural
parts procedurally or by hand. An existing textured mesh can be cleaned directly
without neural inference. Automatic voxel hole-filling is deliberately **not**
applied to props: it could close doorways, ladder gaps and hollow structures.

## Build one candidate

```bash
./tools/asset_pipeline/build_asset.sh S1 --prompt
./tools/asset_pipeline/build_asset.sh S1 --image path/to/hut.png
./tools/asset_pipeline/build_asset.sh S2 --mesh path/to/barrels.glb
./tools/asset_pipeline/build_asset.sh E3 --mesh path/to/vertex_coloured_brush.glb
```

The default is quality for IDs with `quality_tris`, standard otherwise. S1 has a
6,000-triangle quality budget versus its 1,500-triangle standard budget. These
are explicit ceilings, not a claim that more triangles always improve quality.
The instanced vegetation budgets remain unchanged.

Quality image generation uses 1024 resolution, 12 source steps, seeds 1/18,
2K textures and a retained material cache. A separate texture pass uses 24 steps
and seed 42 on the prepared mesh, followed by size/origin correction. It runs by
default for TRELLIS image builds. Use `--no-retexture` to inspect the original
texture first, or when the source texture already meets the reference.

```bash
# Reuse a completed source job from an earlier build without repeating generation:
./tools/asset_pipeline/build_asset.sh S1 --image reference.png \
  --source-run /absolute/path/source/run.json --no-retexture

# Texture-only refinement of a prepared mesh using its prepared reference:
./tools/asset_pipeline/build_asset.sh S1 --mesh prepared.glb \
  --retexture --prepared-reference prepared_input.png
```

The source run must match the image hash and have its raw GLB and prepared image
saved alongside `run.json`. `--prepared-reference` means the image has already
been background-removed/prepared by generation; it is not an arbitrary photo.

Other options:

- `--variant a` selects the variant; outputs always use a fresh job directory.
- `--profile standard|quality` selects an existing manifest budget.
- `--backend triposr|trellis2` selects image inference. Texture-only meshes must
  use the material-preserving route; vertex-mode inputs need vertex colours.
  TRELLIS image generation is refused for vertex-only vegetation before it runs.
- `--view front|three-quarter-right|three-quarter-left` applies an explicit yaw
  correction of 0/+45/-45 degrees. Default `front` applies no correction. Inspect
  the doorway/front orientation; do not assume the model inferred it correctly.
- `--yaw DEGREES` overrides that preset for other orientations (the reviewed S1
  source required `--yaw -90` to place its doorway at +Z).
- `--auto-square` opts into footprint alignment; it is no longer automatic.
- `--mesh-colors linear|srgb` controls vertex-colour decoding for supplied meshes.
- `--output-dir` must be empty. `--skip-preview` supports a host without Godot/display.
- Old `--skip-import` / `--keep-remote` are accepted for compatibility: candidates
  are never installed by the builder, and remote intermediates are always retained.

## What is preserved and checked

Blender keeps UVs, textures and per-surface materials in preserve mode. It keeps
small disconnected parts by default, including stilts and rungs. Vertex mode
stylizes existing vertex colours; it refuses texture-only input instead of
turning it grey. Both routes export flat face normals for the game's faceted
style, clearing imported custom/smooth normals on the game mesh while retaining
the detailed master. All output is static, Y-up, front +Z, base-centred, and sized
according to the manifest. Supplied meshes must be self-contained GLBs; pack
external OBJ/FBX textures first. Rigged/animated inputs are rejected.

Before decimation, cleanup splits non-manifold junctions with more than two
incident faces into separate surface sheets, preserving faces and loop UVs.
This must happen before the first collapse: repairing after a stalled collapse
can satisfy a triangle count while leaving distorted geometry. Four-angle visual
review remains mandatory; this is not a watertightness or collision-mesh guarantee.

The validator walks the active scene hierarchy, applies node transforms, counts
instances, checks accessor/index bounds and finite geometry, rejects zero-area
triangles, and checks strict triangle budget, world-space size, ground position,
centering and material/UV coverage. Vegetation must have vertex colours on every
surface and only one surface. Other props permit up to eight material surfaces.
It is a technical gate, **not** a visual quality score.

```bash
# Full installed set, allowing each ID's explicitly declared quality ceiling:
python3 tools/asset_pipeline/validate_assets.py --profile quality
# Check a standard candidate against its tighter budget:
python3 tools/asset_pipeline/validate_assets.py candidate/E3_brush_a.glb --profile standard
```

Godot's `AssetLibrary.gd` bakes node transforms while preserving separate surfaces,
UVs and original materials, and enables vertex-colour albedo when COLOR_0 is
present without mutating the shared source material. Existing procedural fallbacks and intentional
ember/ash material overrides remain supported.

`artifacts/.gdignore` excludes build evidence from Godot's resource scan. Every
new `pipeline_source/` also receives `.gdignore`: historical copies of scripts
with `class_name` must never shadow the live game classes. Re-index with
`godot --headless --editor --quit --path .` after adding this protection to an
existing checkout.

## Review and install

Candidates live under `artifacts/prop_candidates/<unique-job>/`, with source hash,
script snapshots, manifest/profile, stage status/timing, logs, normalized detailed
master, budgeted GLB, validation results and `preview.png`. The S1 preview includes
the current procedural hut. Look at all four sides, structural openings, small
parts, texture continuity, shading and readability at gameplay distance.

For S1, inspect the candidate in the actual game scene before installation:

```bash
godot --path . \
  --script tools/asset_pipeline/preview_hut_in_game.gd -- \
  /absolute/path/candidate/S1_field_hut_a.glb /absolute/path/game-preview
```

This renders gameplay and close-up views through `AssetLibrary` without changing
installed assets. Use `installed` in place of the candidate path for a baseline.
Previews use the project's configured renderer (currently Forward+), matching the
game. Do not approve colour fidelity from a forced Compatibility-renderer shot:
its vertex-colour handling differs from Forward+.

## Cohesive authored set

`gpu/build_cohesive_set.py` is the deterministic Blender source generator for
three pines, three bamboo clumps, four brush variants, barrels and the drone.
It reads `palette.json`; sources have flat normals, one matte vertex-colour
material and no textures. Thin culms and leaves are actual geometry. This route
uses CPU Blender and does not need neural inference or reserve GPU memory.

Run it in Blender with `--out <empty-folder> --palette <palette.json>`, then pass
each resulting GLB through `build_asset.sh --mesh`, using the ID, variant and
profile in the generated `sources.json`. Sources contain 260/360/136 triangles
per pine/bamboo/brush, 464 for the barrel set, and 428 for the drone body. Keep
vegetation within its standard budget; S2 uses its explicit quality ceiling.
V1's motor centers are at X/Z ±0.48 m after normalization to 1.2 m width. Its
rotors are created and animated by `ForestryDrone.gd`, above the hub tops.

The reviewed set and its source/runtime snapshots are recorded in
`artifacts/cohesive_props_20261002/`. For a full-set game preview:

```bash
godot --path . --script tools/asset_pipeline/preview_set_in_game.gd -- \
  artifacts/cohesive_props_20261002/build_results.json /absolute/path/game-preview
# Use "installed" instead of build_results.json to check the installed set.
godot --headless --path . --script tests/test_cohesive_props.gd
```

## Installation

```bash
python3 tools/asset_pipeline/install_asset.py /absolute/path/candidate --reviewed
```

Run this only after that candidate has been visually reviewed. Installation
rechecks the candidate hash and current manifest, saves a previous-asset backup,
atomically replaces the GLB, then imports in Godot. Import failure restores the
previous GLB (or removes a new one) and attempts a recovery import. Errors and
recovery results are recorded in the candidate's `installation_*` folder.
The game sees a new asset on restart or `AssetLibrary.reload()`.

Not every manifest ID has placement code yet: E6–E9, S3–S5, T2 and V3 still need
scene integration. Building those assets does not automatically place them.

## Dependencies and verification

Uses the existing `gpu` SSH host, `~/aienv/bin/python3`, Blender 4.5.14 and the
native TRELLIS.2 runtime documented in the character pipeline. The runner checks
GPU health and at least 20,000 MiB free before TRELLIS work, 6,000 before TripoSR.
This is a start-time check, not a memory reservation: another process starting
during inference can still cause an out-of-memory failure. Schedule heavy runs
when the GPU is available; the builder never stops other workloads or silently
downgrades generation quality. Blender cleanup runs on CPU; Godot renders
locally. The native source runner retains its runtime hashes and cache locations.

```bash
python3 -m unittest discover -s tools/asset_pipeline/tests -v
# Include real Blender preservation checks where Blender is installed:
BLENDER_BIN=/path/to/blender python3 -m unittest discover -s tools/asset_pipeline/tests -v
godot --headless --path . --script tests/test_prop_materials.gd
godot --headless --path . --script tests/test_skeletal_character.gd
godot --headless --path . --script tests/test_all.gd
godot --headless --path . --fixed-fps 60 --quit-after 120
```

The regression suite covers the previous wrong-scale/degenerate-face false
passes, hierarchy/instances, invalid indices, missing colours, strict budgets,
review/hash gates, import rollback, UV texture retention, and preservation of
small disconnected geometry. Test cubes are fixtures, not finished game props.

The first S1 quality benchmark is recorded in
`artifacts/asset_pipeline_v2/hut_source/`: its 1024 source run failed in shape
decoding with GPU out-of-memory after another workload started. It produced no
candidate GLB and nothing was installed. Texture-preserving mesh and vertex-colour
routes passed end-to-end fixture builds; the new hut's visual quality and the
prop-specific fresh-texture route still need a completed GPU benchmark.

The retry in `artifacts/asset_pipeline_v2/hut_lowpoly_v2/source/` completed on a
clear GPU using the stricter low-poly reference. Its reviewed derivative is
`hut_lowpoly_6000_repaired/`: 5,845 triangles, 3.3 m height, one textured surface,
flat normals, and a -90-degree front correction. The native texture was accepted
after four-angle and in-game review. The 1,500-triangle attempt remained over
budget and was rejected. This run also exposed the need to split non-manifold
junctions before decimation. No prop-specific fresh-texture benchmark was needed
for this accepted source texture; that optional route is still unverified here.


## Asset polish source set (2026-10-02)

`gpu/build_polish_props.py` authors nineteen deterministic, matte faceted props.
Run in Blender beside `build_cohesive_set.py` with `-- OUTPUT palette.json`.
Pass the output through the existing standard candidate/review/install workflow.
It changes crown masses, tool construction and structure silhouettes while
preserving manifest budgets. Current installed evidence and remaining integration
work: [polish handoff](ASSET_POLISH_HANDOFF_20261002.md).

`export_polish_vfx.gd` packs generated flame/mist/ash sources;
`validate_polish_vfx.gd` verifies dimensions, neutral channels and atlas padding.
`review_polish_effects.gd` reviews game materials across lighting states and
asserts the installed mist/ash hooks. The updated prop, equipment and VFX review tools isolate save paths.
