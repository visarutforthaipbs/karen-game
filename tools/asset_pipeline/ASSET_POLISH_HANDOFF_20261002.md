# Asset polish installed — 2026-10-02

Installed 19 revised static models and three effect textures after the whole-game
asset audit. This pass preserves the approved cast: all six rigged GLB SHA256
hashes match the pre-pass snapshot. No gameplay scripts, UI scripts, character
scenes, animation clips, audio or `tests/test_all.gd` were edited.

**Follow-up resolved:** the player hose, Kha-nae rake palm contact and Ta-poh belt
knife are now implemented. See [equipment/motion handoff](../character_pipeline/EQUIPMENT_MOTION_HANDOFF_20261002.md).
The original remaining-work notes below describe the earlier asset-only delivery.

Evidence root **P**: `artifacts/asset_polish_20261002/`. Current installed meshes,
triangle counts, dimensions and SHA256 hashes: `P/installed_props.json`.
Previous production files: `P/rollback/`; individual model installation records
and import backups also live inside each candidate folder. Earlier v1.2 counts
are historical for the assets listed below.

## Installed batches

| Batch / ID | Variants | Triangles each | Improvement / contract |
|---|---|---:|---|
| Effects X1 | one | — | New 512px 4×4 greyscale flame atlas, broader cores, eight-pixel bottom padding |
| Effects X5 | one | — | New 512px 2×2 neutral mist atlas, used by existing douse/steam hook |
| Effects X6 | one | — | New 64px neutral ash flake, used by existing ash hook |
| Equipment T1 | a | 172 / 200 | Thicker grip, dark protective base and outlet; 0.90m high |
| Equipment T3 | a | 144 / 200 | Stronger shaft, grip sleeve, head collar and teeth; 1.40m high |
| Equipment T4 | a | 228 / 300 | Base rail, exterior inset, strap buckles and hose fitting; 0.46m high |
| Equipment T5 | a | 112 / 150 | Brass collar, larger nozzle and inlet fitting; 0.80m high |
| Environment E1 | a–c | 210 / 300 | Different crown offsets, skirt shapes, lean and low branch masses; 4.20m high |
| Environment E2 | a–c | 400 / 400 | Eleven broad leaf lances per culm, varied leaning five-culm crowns; 3.30m high |
| Environment E3 | a–d | 136 / 150 | Upright/spreading/asymmetric clumps; retained green/dry colour roles; 0.80m high |
| Environment E8 | a–b | 116 / 150 | Bent trunks, uneven cut ends and different branch directions; 1.50m maximum length |
| Structures S3 | a | 812 / 1500 | Raised granary framing/braces, overlapping roof courses, ridge cap; 3.00m high |
| Structures S6 | a | 638 / 1500 | Raked cab/windscreen, sloped bonnet, grille, mirrors, rails and mudguards; 1.89m high |
| Structures S7 | a | 144 / 150 | Broad red woven bands and contrasting knot on indigo cloth; 0.46m high |

All models retain base centring, Y up and +Z front. All were built against the
**standard** ceiling; no manifest budget was raised. E9 grass remains exactly
40 triangles per variant. E7 mating planes and V3 orientation are unchanged.
Mu-naw keeps her separate bamboo/brass tank; the yellow T4 is the player tank.
X2 smoke and X3 ember are unchanged.

## Review and tests

- Four-angle sheets: `P/review/{pines,bamboo,brush,logs,equipment,structures}.png`.
- Gameplay-distance candidate staging: `P/review/environment_game/` and
  `P/review/structures_game/`, each at 12/22/44m.
- Actual player attachment review: `P/review/held/`.
- Installed crew motion: `P/review/motion/` (idle, ignite, rake, spray, moving work,
  cough and run, four angles, plus close-ups). This exposes remaining hand-contact
  limitations; it is not certification of perfect gripping or arbitrary poses.
- Current game/ending captures: `P/game/{main,main_burn,burn_close,famine,crackdown}.png`.
- Actual VFX materials at gameplay distances and day/18:30 inversion/19:48 light:
  `P/vfx/temporal/`. Eight temporal samples per lighting state and eight douse
  samples. `douse_hooks.json` verifies both new production texture paths.
- `P/vfx/validation.json`: dimensions, all frames populated, equal RGB channels,
  transparent frame borders. Flame alpha wrap difference 0.0473 is below the
  largest internal transition, 0.1291; this is not a motion-interpolation guarantee.
- `tests/test_all.gd` passed after **each of four installation batches**, zero
  failures: `P/test_all_{vfx,equipment,environment,structures}.log`.
- Whole installed prop set passes `validate_assets.py --profile quality`;
  individual candidates also pass their tighter standard budgets. All 45 GLBs
  remain installed, covering 26 manifest IDs.
- Prop material preservation test and 120-frame headless game smoke pass.
- The full suite intentionally attempts to read corrupt JSON in its corrupt-save
  test and still reports two known ObjectDB exit warnings. Review harnesses can
  report exit leaks; no new production script error is being waived.

The first bamboo candidate remained too sparse and was replaced with the reviewed
400-triangle revision. An initial structure-sheet path used the source filename
instead of the canonical S3 output name; corrected before review. The first douse
check filtered by node name and missed Godot's auto-renamed second emitter;
corrected to inspect all one-shot particles. Final captures use the corrected
harnesses. Review save/settings/log paths are isolated under P.

## Equipment anchors and remaining GAME work

`P/equipment_anchors.json` records points in the **normalized GLB's local metres**.
Keep the current held-tool offset `(0,-0.22,0)` for these replacements. After
base-centred bounding-box normalization, actual grip centres are:

| Tool | X | Y | Z |
|---|---:|---:|---:|
| T1 | -0.003957 | 0.219759 | -0.000856 |
| T3 | 0 | 0.217513 | -0.006040 |
| T5 | 0 | 0.215890 | -0.003373 |

These small offsets are recorded rather than changing the pipeline's centring.
T4's source dimensions were constrained to the existing height/depth envelope;
final exact bounds are in the inventory. The existing lowered tank attachment
continues to clear the head. S7 continues to use the existing `(0,0.40,-0.20)`
C6 attachment; no new runtime offset is needed.

The visible sprayer fittings are now delivered. A connecting **player hose**
still needs GAME to update its endpoints each frame: T4 outlet
`(0.150,0.055,-0.096750)`, T5 inlet `(0,0.024533,-0.075990)`, transformed through
those prop instances. Preserve Mu-naw's existing separate hose/tank path. The
borrowed companion sprayer also needs its own endpoint connection.

The approved character meshes have no individual finger bones. Open-hand grips
and Kha-nae's crossing hands during the rake pose remain visible at close range
(`P/review/motion/Player_rake_view0.png`). These are existing animation/contact
issues, not solved by thickening a handle. GAME/character-animation work should
adjust two-hand targets and work poses while retaining the locked face/costume.
T2 belt/off-hand placement remains a runtime-hook task.

Other audit follow-ups remain distinct from this installed asset pass:

- **AUDIO + GAME:** shared-bar, shared-duration music stems and phase-preserving
  playback. Existing audio was not replaced or time-stretched without audition.
- **GAME:** identify a live S4 house placement before generating unreferenced
  house variants; existing Hearth uses a painting.
- **GAME/UI:** fix Hearth 4:3 clipping through layout.
- **GAME/build:** exclude/archive unused legacy models and candidate audio after
  export dependency review; profile texture compression on target hardware.
- **GAME/VFX:** the existing colour ramp still makes flames warm gold/brown in
  bright daylight. New silhouettes improve core coverage; art alone does not
  change tint, overdraw or opacity. Evening/inversion captures remain readable.

## Reproduction / provenance

3D: `tools/asset_pipeline/gpu/build_polish_props.py`, existing `Shape` helper and
`palette.json`, using CPU Blender on the GPU machine. No neural GPU job or paid
Meshy character generation was needed. Each source then went through
`build_asset.py --mesh --profile standard`, visual review and
`install_asset.py --reviewed`. Source/candidate pipeline snapshots are retained.

2D: built-in image generation. Exact prompt set and mode: `P/vfx/prompts.json`.
Unmodified originals: `P/vfx/source/{flame,mist,ash}.png`. Technical packing only
through `export_polish_vfx.gd` (size, neutral channels, padding and alpha cleanup).
Production: `assets/vfx/{flame_sheet,mist_sheet,ash_flake}.png`.

No Meshy character identity, source reference, portrait or rig was regenerated.
Preservation proof: `P/character_preservation.json` (all six true).
