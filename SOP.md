# STANDARD OPERATING PROCEDURE (SOP)
## Character production — refined mesh, rig, animation and Godot

**Project:** Satellite Shadow (เงาเมฆา / ไร่หมุนเวียน)  
**Version:** 3.1 — 2026-10-02

## 1. Current production route

Reference image → TRELLIS.2 source/cache → surface reconstruction → fresh texture
pass → game mesh → visual review → calibrated skeleton/skin → animation review
→ Godot integration → runtime checks.

The Mac runs Godot and orchestrates work over `ssh gpu`. The RTX 3090 host runs
native TRELLIS.2 and Blender 4.5.14. The earlier TripoSR / 2,500-triangle pipeline
remains a prototype option, not the quality route for the current characters.

Installed v3.1 character status (2026-10-02):

| Character | Mesh / rig | Animation and gameplay |
|---|---|---|
| Kha-nae | 14,394 triangles, 19 bones | Idle, Walk, Run, ToolUse; independent ignition, two-hand rake and spray layers |
| Ta-poh | 19,900 triangles, 19 bones | Idle, Walk, Run, ToolUse; separate one-hand clearing blade and borrowed sprayer |
| Mu-naw | 13,957 triangles, 21 bones | Idle, Walk, Run, ToolUse; free arms, dress controls, separate faceted tank, wand and flexible hose |
| Mae-Lu | 19,900 triangles, 21 bones | Idle, Walk, Run, ToolUse, Talk, Granary; live village granary portrait with ration-selection gesture |

Use `rig_profiles/<name>_v31.json` for these meshes. Legacy profiles describe
older geometry and remain for rollback. All new rigs preserve the selected
geometry, UVs and materials, with four normalized influences per vertex.
The generic ToolUse clip is an inspection/backwards-compatibility clip; gameplay
uses semantic work layers while locomotion continues. Mae-Lu has no burn-field AI.

The user explicitly authorized rigging after the reference gate was explained.
Documentary cultural verification remains open; this installation does not claim
that generated costume motifs have been authenticated. See
[cast status](tools/character_pipeline/CAST_V31_STATUS.md) and
[gameplay motion](tools/character_pipeline/gameplay_motion.md).

Evidence and rollback: `artifacts/character_rigs_v31/`. All four passed baked
clips, four-angle pose/tool review, real-renderer runtime deformation, slope/cough
sampling, exported skin/material tests, actual controller tests and the complete
gameplay suite. These are sampled gameplay checks, not cinematic rig approval;
fingers/faces and arbitrary deep crouches are not rigged or certified.

A successful technical check does not establish visual likeness. Keep source
images, settings, intermediate outputs, previews and validation reports.

**Mandatory low-poly style gate — both character and prop pipelines:** Follow
PRD §9.1. References and finished assets must use simple angular silhouettes,
visible faceted shading, broad colour areas and restrained painted details.
Simplify cultural patterns without losing their identity. Reject photorealistic
surfaces, dense microtexture and glossy realism. Compare four-angle previews and
the in-game view with the existing cast, props and terrain before installation.
Higher resolution or a larger triangle ceiling never waives this style review;
surface smoothing for repair must not erase the intended faceted appearance.

## 2. Prepare and generate the character

Use one isolated full-body A-pose reference with visible hands/feet and separated
limbs. It must express the desired face, proportions and garment patterns.
Preserve Karen cultural details and character identity from the reference.

For v3.1, distinguish supplied concept art from documentary cultural evidence.
Record sources and uncertainties in each character's reference manifest. Check
the A-pose proportions before GPU generation, then check the resulting surface
for visible facets, dress/leg separation and unbridged hands. A long dress may
need different surface repair and rig weights from Kha-nae's successful recipe.
Normally visual and cultural lock precede final rigging. The user's later
2026-10-02 requests explicitly authorized completing all four and then proceeding
with rigging despite the documented reference gap. Keep that gap visible;
track that work in [cast v3.1 status](tools/character_pipeline/CAST_V31_STATUS.md).

```bash
python3 tools/character_pipeline/run_refined_character.py \
  --image artifacts/character_expansion_20261001/references/khanae_3d_reference_v2.png \
  --name khanae --height 1.20
```

This uses 1024 generation, saved PBR voxels, 512 surface reconstruction, smoothing,
a 40K game budget, then fresh 2K texture generation at 24 steps / seed 42. It
restores height and grounding after texturing and produces a Godot preview.
See [pipeline README](tools/character_pipeline/README.md) for cache reuse and
runtime dependencies. Neural jobs require the runner's GPU health checks and
20,000 MiB free VRAM; never stop other workloads automatically.

Outputs are candidates under `artifacts/character_candidates/`, not automatic
production replacements. Inspect front, side and back against the reference.
Reject damaged hands, holes, poor likeness or broken patterns even if validation
passes. The refined recipe has been reproduced on Kha-nae; it is not a guarantee
of first-attempt success on every new character.

Close-up and silhouette review must also look for tunnels through hair, wraps,
collars and hems. A closed triangle boundary or a “watertight” report does not
prove that these regions are solid: a rear headwrap tunnel can expose the front
face. Do not try to fix that solely by repainting. Preserve the source and repair
or reconstruct the geometry, then review the changed silhouette and rebaked colour.
All four v3.1 experiments and rejected alternatives are tracked in
`tools/character_pipeline/CAST_V31_STATUS.md`; numeric validation is not final approval.

## 3. Rig the reviewed mesh

Rigging is the next production step for articulated hero movement. The existing
procedural animator remains a fallback for characters that are not yet skinned.

```bash
python3 tools/character_pipeline/run_rig.py \
  --input artifacts/khanae_refined_pipeline_validation/candidate/khanae_40000tris.glb \
  --profile tools/character_pipeline/rig_profiles/khanae.json
```

This runs headless Blender on the compute host, preserves the reference mesh and
textures, creates a calibrated skeleton and skin, and exports a `.blend`, rigged
GLB, reports and source snapshots into a new candidate folder. It uses CPU work;
it does not run another neural generation or upload to an external rigging site.

The Kha-nae profile checks the exact input hash. For a new mesh or character,
review joint landmarks and anatomical weight regions before making a new
profile. Merely adding another hash is not calibration. Each profile selects character-specific anatomical regions. The legacy Mu-naw body
midline is offset from the mesh bounds by projecting equipment. Inspect the
body, not just the bounding box; this is not a universal automatic rigging service.

See [rigging guide](tools/character_pipeline/rigging_guide.md) for bones, skinning,
accessories and animation limits.

## 4. Animation and deformation review

Required baked clips: Idle, Walk, Run and legacy ToolUse. Gameplay work poses
are runtime layers and must be tested separately from the exported clips. Review each from four angles,
including maximum arm and leg bends. Verify:

- Normalized weights, at most four influences, no unweighted vertices.
- Head and hat remain rigid; the basket core follows the hip with a blended
  attachment where the generated surface joins the clothing.
- No hand-to-torso stretching, leg cross-influence or extreme joint collapse.
- Feet remain grounded, loops repeat, and in-place clips do not move the actor.
- UV textures survive skinning/export; accessories follow their attachment bones.

The cast now has tool-specific runtime poses, target-facing, movement during
work and bounded foot correction. Finger closure and facial animation remain
optional for the current camera. Review stride/contact at gameplay speed and
terrace edges: the presence of IK or a Run clip alone does not prove perfect feet.

To mark a character gameplay-ready, review its role-specific motions in the
actual game: stationary and moving tool use, target turns, slopes, smoke slowdown,
companion task interruption and end-of-day stopping. Match tool contact/effects
to the action without silently changing gameplay reach, cadence or balance.
Review two-hand tool grips and rigid accessory attachment at maximum bends.
Keep the accepted low-poly silhouette, faceted surfaces and cultural details.

## 5. Install and connect in Godot

Keep the previous scene/model for rollback. Install reviewed GLBs under
`assets/models/<name>_rigged.glb` and instance them in the character scene.
All three scenes use `scripts/SkeletalChibiAnimator.gd` with their own
`character_profile`. The legacy `ChibiAnimator.gd` remains a fallback.

Controllers send `set_work(kind, active)`, `set_environment(grid, coughing)` and
`update_animation(delta, velocity, face_dir)`. The animator manually advances
locomotion, resets bone poses before layering and keeps work separate from gait.
`cancel_work()` handles new orders, rally, tool changes and the satellite stop.
Effects are emitted only when the game successfully changes a cell; their visual
nodes never consume water or change fire simulation state.

Reimport and run the relevant checks after integration:

```bash
godot --headless --editor --quit --path .
godot --headless --path . --script tests/test_skeletal_character.gd
godot --headless --path . --script tests/test_character_materials.gd
godot --headless --path . --script tests/test_gameplay_motion.gd
godot --path . --script tests/test_motion_deformation.gd
godot --headless --path . --script tests/test_all.gd
godot --headless --path . --fixed-fps 60 --quit-after 120
```

Capture the installed character, animations and hand-held tool in the real scene:

```bash
godot --path . \
  --script tools/character_pipeline/preview_rig_in_game.gd -- \
  /absolute/path/to/new_demo_frames
```

The preview runs in-place Idle, Walk and ToolUse on the real player model. It
is a visual animation check, not a substitute for testing movement, targeting
and tool gameplay. Keep acceptance notes with the render and test logs.
Use the project's default renderer for appearance acceptance so material and
colour handling match the shipped scene.

For the current cast and runtime layers, also capture:

```bash
godot --path . --script tools/character_pipeline/review_gameplay_motion.gd -- \
  /absolute/path/to/new_motion_review
```

The deformation test needs a real renderer to bake the current skinned pose;
headless rendering cannot provide that mesh. It samples runtime work and moving
work, complementing Blender's baked-clip checks. Keep rejected candidates and
never weaken the stretch threshold merely to make a pose pass.
