# Kha-nae reference correction — 2026-10-02

Replaced only `assets/models/khanae_rigged.glb` and
`assets/ui/portraits/khanae_256.png`. The user rejected the previous Kha-nae face
and proportions; other characters remain approved and unchanged. This correction
has technical and agent visual review, but does not claim subsequent user approval.

Evidence root **B**: `artifacts/character_candidates/khanae_likeness_20261002/`.
The exact supplied `Meshy_AI_khanae_clean_front.png` is copied unchanged to
`assets/reference/characters/khanae/02_clothing/khanae_user_locked_v02.png`.
Its SHA-256 is `7dcbceea7775226325c2b5690b4c70a21289c1ebebb973af22e3326bd3197c76`.
Character direction remains `character_direction_v3.1.md`, section 6.

## Cause and correction

The previous generation used `khanae_apose_v01.png`, a simplified derivative
that omitted gear. Its different face and proportions should have failed the
likeness review despite passing movement tests. The correction uses the exact
user image without a new reference or pose override. The new model restores the
canteen and striker/sling detail, with eyes, brows and beard closer to the supplied
face. Image-to-3D remains an approximation; the comparison image exposes the
remaining differences instead of claiming pixel-identical reconstruction.

Meshy generation task: `01a0fb7f-edac-70bc-8f99-2ef85309153f` (30 credits).
Meshy rig task: `01a0fb85-3b15-72e8-93e9-35f28fda29f9` (5 credits).
Total correction API cost: **35 credits**, recorded in saved task results.
No local neural character generation was used.

The Meshy source contains 20,358 triangles, exceeding the 20K production ceiling.
The reviewed prepared surface has **19,798 triangles**, embedded albedo/UVs,
one matte faceted surface, 1.20 m height, +Y up, +Z front and base-centred origin.
The delivered rig has 19 bones and Idle, Walk, Run, ToolUse clips. No game offsets
or scene hooks changed. Installed SHA-256:
`b9c2b70e523d6dd61a6ddf0f0aeb1399c751c87e590c1a42560b5b7bd541ef76`.

## Rigging and why Blender was involved

Meshy supplies cloud auto-rigging and animation; an RTX GPU is not required.
This delivery uses Meshy's rigged source but adapts its joints to the existing
game's named skeleton and procedural work layers. Its baked clips are the local
game clips, not Meshy library animations. Blender ran on the CPU of the machine
named `gpu`. The game controller was not rewritten during asset delivery.

Accepted adapter calibration: `B/rig_v12/`. Native Meshy limb weights are mapped
to game bones and transferred to the prepared surface; impossible arm influence
on the centre torso is removed, and head/hat are kept rigid. Broad analytic
reweighting and global smoothing attempts failed motion gates and were rejected.
The final local correction preserves the source surface, UVs and albedo. The
unchanged maximum edge-stretch gate is 3.5 for edges longer than 3 mm.

Exact build scripts are saved in `B/rig_v12/adapt_khanae_locked.py` and
`B/rig_v12/rig_character.py`. This is a Kha-nae-specific recipe, not a general
replacement adapter. Input is `B/meshy_rig.glb`, with
`B/prepared/khanae_19900tris.glb` next to it in the prepared directory. The build
used Blender 4.5.14, `--python-exit-code 1`, `--name khanae --height 1.2`, and a new
output directory. Blender rest/final files remain on the GPU host under
`/home/visarut298/character_candidates/khanae_likeness_20261002/rig_v12/`.
The source report's inherited provider label is broad; the weight description
in this handoff accurately describes the delivered v12 recipe.

For future work, start with Meshy's native rig and animation exports and preserve
compatible skin/clips. Local rebuilding is optional. If native rigs need game
controller changes, hand the concrete mapping and tool requirements to GAME;
do not modify scripts/ or ui/ as part of asset delivery.

## Validation and review

All evidence paths below are relative to B.

| Check | Evidence / result |
|---|---|
| Geometry, UV, texture, materials, weights, bones, clips and dimensions | `rig_v12_validation.json`: pass |
| Prepared vs rigged unordered surface triangles/UVs (5 decimal places), exact albedo bytes | `rig_v12_preservation.json`: pass |
| All frames of four baked clips | `rig_v12/rig_report.json`: worst edge stretch 2.375 |
| Actual runtime work, moving work and gait, flat ground | `rig_v12_runtime_flat.json`: 3.1497, pass |
| Same with 20% slope and cough | `rig_v12_runtime_slope.json`: 3.1505, pass |
| Installed full gameplay suite | `installed_all.log`: RESULT: OK (0 failures) |
| Installed articulation, action repeat/root/socket | `installed_skeletal.log`: pass |
| Installed cast geometry/skin/animation contract | `installed_cast.log`: 0 failures |
| Real controller movement, water use, interruption and companion actions | `installed_motion.log`: 0 failures |
| Headless 120-frame smoke run | `installed_smoke.log`: pass |
| Other five rigs, four C6 meshes and four portraits unchanged | `unchanged_others_verified.json`: all 13 hashes match |

Existing exit-time ObjectDB warnings remain: two in the full suite and eight in
the skeletal/motion checks, matching the earlier delivery baseline. These are not
represented as fixed. Only Kha-nae's exact triangle fixtures were updated in
`test_skeletal_character.gd` and `test_v31_assets.gd`; no assertions were removed.
No scripts/, ui/, or tests/test_all.gd edits were made by this correction.

Reviewed images:

- `comparison_final.png`: user reference, rejected previous model, corrected rig;
  full-body and face crops with corresponding source manifest.
- `rig_v12_review.png`: four-angle idle and work poses. This generic review tool
  shows a rake even in its spray row; use the actual gameplay review for tools.
- `gameplay_review/`: actual installed Main scene, four angles of idle, ignition,
  raking, spraying, moving work, cough and running; individual work/run close-ups.
- `khanae_256.png`: portrait rendered from the installed mesh, not a new face.

Hands retain the existing open-hand tool grip; individual finger closure, facial
animation, cloth collision and arbitrary extreme poses are not certified.

## Rollback

`B/rollback/khanae_rigged.glb` and `B/rollback/khanae_256.png` preserve the previous,
user-rejected appearance. Reverting also requires restoring its 19,593-triangle
fixtures, registry/portrait hashes and reimporting/testing. Do not use a blanket
git reset because this checkout contains other tasks' concurrent work.
