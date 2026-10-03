# STANDARD OPERATING PROCEDURE (SOP)
## Character production — Meshy, rig, animation and Godot

**Project:** Satellite Shadow (เงาเมฆา / ไร่หมุนเวียน)  
**Version:** 3.3 — 2026-10-02

## 1. Current production route

**User decision, 2026-10-02:** Use Meshy for new character generation. Stop local
TRELLIS.2 / TripoSR character generation development. **Updated user decision,
2026-10-03:** Meshy may also generate selected prominent props; retain the local
pipeline for cleanup, validation and efficient procedural assets. See the
[remaining-credit plan](tools/asset_pipeline/MESHY_EXPANSION_PLAN_20261003.md).
Existing installed characters remain
available until reviewed replacements are ready.

Approved reference → Meshy character candidate → low-poly and likeness review
→ game mesh preparation → rig/skin and animation → gameplay motion review
→ Godot integration → runtime checks. See
[Meshy setup and delivery procedure](tools/character_pipeline/MESHY_SETUP.md).
The Meshy cast is installed: five rigged characters, the ranger slate variant,
four static C6 villagers and five matching portraits. See the
[Meshy cast handoff](tools/character_pipeline/MESHY_CAST_HANDOFF.md) for counts,
review evidence, tests and rollback. All current principal meshes are under
20,000 triangles; C6 stays below 3,000 per model.
Meshy's rigging/animation tools can supply candidates, but exported skeletons,
clips and equipment sockets must be checked against the actual game contract.
Never assume the old calibrated profiles fit a new Meshy mesh.

**Rigging clarification, 2026-10-02:** Meshy provides cloud auto-rigging and
animation; neither requires our RTX GPU. Start by reviewing Meshy's native rig
and walking/running exports. Preserve its skin and use suitable Meshy library
animations where they fit. Do not rebuild every character rig by default.
The current game expects named joints, clips and procedural tool layers; record
any actual incompatibility before applying a local conversion. Blender conversion
and validation can run on a CPU; using the host named `gpu` does not mean neural
inference is running. Missing game-specific actions still need integration and
movement/tool tests. Runtime-hook changes remain GAME-owned.

Kha-nae's exact-reference correction is installed; see
[likeness correction and validation](tools/character_pipeline/KHANAE_LIKENESS_HANDOFF.md).
The other approved characters were not changed by that correction.

### Previous local route and installed cast (historical)

The Mac runs Godot and orchestrates work over `ssh gpu`. The RTX 3090 host runs
native TRELLIS.2 and Blender 4.5.14. The earlier TripoSR / 2,500-triangle pipeline
and refined local routes are retained for history and rollback, not new character
generation. Local mesh preparation, preview and rig validation remain useful.

Previously installed local v3.1 character status (superseded by Meshy):

| Character | Mesh / rig | Animation and gameplay |
|---|---|---|
| Kha-nae | 14,394 triangles, 19 bones | Idle, Walk, Run, ToolUse; independent ignition, two-hand rake and spray layers |
| Ta-poh | 19,900 triangles, 19 bones | Idle, Walk, Run, ToolUse; separate one-hand clearing blade and borrowed sprayer |
| Mu-naw | 13,957 triangles, 21 bones | Idle, Walk, Run, ToolUse; free arms, dress controls, separate faceted tank, wand and flexible hose |
| Mae-Lu | 19,900 triangles, 21 bones | Idle, Walk, Run, ToolUse, Talk, Granary; live village granary portrait with ration-selection gesture |
| Ranger C5 | 19,800 triangles, 19 bones; olive and cold grey-green textures | Idle, Walk, Run, Scan, Photograph, Point, RadioTalk, Escort; separate flashlight/tablet. Asset scenes delivered; event calls remain GAME work |

Use `rig_profiles/<name>_v31.json` for the four crew and `rig_profiles/ranger_v11.json` for C5. Legacy profiles describe
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
The user's 2026-10-02 correction rejects the first Meshy Kha-nae likeness. Use
`assets/reference/characters/khanae/02_clothing/khanae_user_locked_v02.png` as his
exact visual reference. Other Meshy characters remain approved. Compare face
width, eyes/brows, beard, head-to-body proportions, silhouette and required gear
against the locked image both before rigging and after the final export. A
prepared derivative may not silently supersede the user's reference.

**Mandatory low-poly style gate — both character and prop pipelines:** Follow
PRD §9.1. References and finished assets must use simple angular silhouettes,
visible faceted shading, broad colour areas and restrained painted details.
Simplify cultural patterns without losing their identity. Reject photorealistic
surfaces, dense microtexture and glossy realism. Compare four-angle previews and
the in-game view with the existing cast, props and terrain before installation.
Higher resolution or a larger triangle ceiling never waives this style review;
surface smoothing for repair must not erase the intended faceted appearance.

## 2. Prepare the reference; generate through Meshy

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

For new characters, follow [the Meshy procedure](tools/character_pipeline/MESHY_SETUP.md).
The recipe below documents the previous local experiments; do not launch it as
the current production route. Its visual rejection criteria still apply to Meshy.

### Archived local generation recipe

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
For a Meshy replacement, inspect its skeleton and animation exports first. Retarget
or recalibrate as needed; the command below is a local rigging option for a mesh
with a reviewed, matching profile, not an automatic step for every Meshy export.

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


## C5 texture variants and export timing

The Ranger v1.1 pass found that Blender re-import/export can resample clips at
its default scene frame rate. A texture variant must not silently alter geometry,
skinning or animation timing. `preserve_rig_texture_variant.py` appends the reviewed
baked albedo to the original GLB and redirects only the image bufferView; original
mesh/skin/animation bytes stay unchanged. Validate the resulting GLB in Godot.
`check_ranger_rig.gd` samples all eight exported clips and checks finite vertices,
edge stretch and grounding independently of Blender. The asset contract test
also checks identical clip lengths for both palettes. See the v1.1 asset handoff
for evidence and remaining grip/contact limitations.


### Meshy motion acceptance lesson — 2026-10-03

A provider-successful animation job is still a candidate. Test one transfer onto
the approved game skeleton before buying a cast-wide batch, including every
affected work layer at zero and moving velocity. The Kha-nae Idle pilot failed
the existing rake edge-stretch gate (5.40 versus 3.5); it was not installed and
the other five planned jobs were not submitted. Keep the approved cast/clip bytes
until a retarget profile passes the gameplay deformation and equipment checks.
Details: [motion and asset handoff](tools/asset_pipeline/MESHY_EXPANSION_HANDOFF_20261003.md).


### Compatible motion overlay — 2026-10-03

The full-body pilot remains rejected. `retarget_meshy_overlay.py` now transfers
local, first-frame-relative Chest/Head motion at a reviewed 0.15 gain over the
approved Idle/Talk/Scan clip anatomy. Root, hips, limbs, cloth controls, skin,
textures and other clips are preserved. It is a restrained overlay, not a full
body motion converter. Keep the 12° overlay envelope and existing 3.5 deformation
limit; test every baked clip and semantic work layer, terrain/cough variants and
actual held equipment before installation. Do not apply this profile to arbitrary
work, walking or crouching clips. The reviewed cast now uses these overlays.
Reproduction and evidence: [completion handoff](tools/asset_pipeline/VILLAGE_COMPLETION_HANDOFF_20261003.md).

### Full gameplay motion and skin refinement — 2026-10-03

The user authorized improving the complete cast. The current six rigs have intentionally refined joint weights, with rest surfaces/UVs/albedo and landmarks preserved. `retarget_meshy_motion.py` supplies validated bind-relative gait candidates; `refine_skin_weights.py` smooths only existing carriers and protects dominant rigid head/bag/hand/foot regions. Do not repeatedly smooth without the approved original weight reference. The accepted route imports at 60 fps, matching its authored sampling. Every named clip must pass 3.5× stretch and 2 mm grounding; semantic work/slope, equipment and actual game checks remain mandatory. [Current delivery, rejected trials and limitations](tools/character_pipeline/RIG_ANIMATION_HANDOFF_20261003.md).
