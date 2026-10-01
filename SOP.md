# STANDARD OPERATING PROCEDURE (SOP)
## Character production — refined mesh, rig, animation and Godot

**Project:** Satellite Shadow (เงาเมฆา / ไร่หมุนเวียน)  
**Version:** 2.0 — 2026-10-01

## 1. Current production route

Reference image → TRELLIS.2 source/cache → surface reconstruction → fresh texture
pass → game mesh → visual review → calibrated skeleton/skin → animation review
→ Godot integration → runtime checks.

The Mac runs Godot and orchestrates work over `ssh gpu`. The RTX 3090 host runs
native TRELLIS.2 and Blender 4.5.14. The earlier TripoSR / 2,500-triangle pipeline
remains a prototype option, not the quality route for the current characters.

Current character status:

- **Kha-nae:** refined 39,799-triangle mesh with 2K textures; calibrated 19-bone
  skeleton, Idle / Walk / ToolUse clips, hand-attached tool, and skeletal animator.
- **Ta-poh and Mu-naw:** textured models with existing whole-model procedural
  animation. They still need their own rig profiles and deformation reviews.

A successful technical check does not establish visual likeness. Keep source
images, settings, intermediate outputs, previews and validation reports.

## 2. Prepare and generate the character

Use one isolated full-body A-pose reference with visible hands/feet and separated
limbs. It must express the desired face, proportions and garment patterns.
Preserve Karen cultural details and character identity from the reference.

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
profile. Merely adding another hash is not calibration. The current skinning
rules are Kha-nae-specific; this is not a universal automatic rigging service.

See [rigging guide](tools/character_pipeline/rigging_guide.md) for bones, skinning,
accessories and animation limits.

## 4. Animation and deformation review

Required initial clips: Idle, Walk and ToolUse. Review each from four angles,
including maximum arm and leg bends. Verify:

- Normalized weights, at most four influences, no unweighted vertices.
- Head and hat remain rigid; the basket core follows the hip with a blended
  attachment where the generated surface joins the clothing.
- No hand-to-torso stretching, leg cross-influence or extreme joint collapse.
- Feet remain grounded, loops repeat, and in-place clips do not move the actor.
- UV textures survive skinning/export; accessories follow their attachment bones.

The first Kha-nae clips are a gameplay foundation, not a finished animation
library: fingers and face are not rigged; separate rake/ignition/spray actions,
terrain foot IK and locomotion stride tuning remain polish work.

## 5. Install and connect in Godot

Keep the previous scene/model for rollback. Install reviewed GLBs under
`assets/models/<name>_rigged.glb` and instance them in the character scene.
Kha-nae uses `scripts/SkeletalChibiAnimator.gd`; other characters continue using
`ChibiAnimator.gd`. Both expose `update_animation()` and `trigger_action()`.

The skeletal controller crossfades Idle/Walk, plays ToolUse once, ignores repeated
triggers until it finishes, and creates Hand.R and Chest attachment sockets.
`PlayerController.gd` attaches the tool and tank to those sockets for rigged
characters. It retains the old tool behavior for procedural characters.

Reimport and run the relevant checks after integration:

```bash
godot --headless --editor --quit --path .
godot --headless --path . --script tests/test_skeletal_character.gd
godot --headless --path . --script tests/test_character_materials.gd
godot --headless --path . --script tests/test_all.gd
godot --headless --path . --fixed-fps 60 --quit-after 120
```

Capture the installed character, animations and hand-held tool in the real scene:

```bash
godot --path . --rendering-method gl_compatibility \
  --script tools/character_pipeline/preview_rig_in_game.gd -- \
  /absolute/path/to/new_demo_frames
```

The preview runs in-place Idle, Walk and ToolUse on the real player model. It
is a visual animation check, not a substitute for testing movement, targeting
and tool gameplay. Keep acceptance notes with the render and test logs.
