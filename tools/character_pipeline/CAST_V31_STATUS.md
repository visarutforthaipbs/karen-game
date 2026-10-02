# Four-character v3.1 production status

User request, 2026-10-02: continue all four characters through the SOP while the
user is away. The active goal is completion, not merely launching generation.
Do not declare perfection from technical validation or a single front render.

## Installed gameplay rigs — 2026-10-02

The user explicitly instructed “do it” after the SOP check identified unfinished
rigging. All four selected candidates now have gameplay rigs installed; the
reference gap remains documented independently of this authorization.

| Character | Triangles / height | Rig and use |
|---|---|---|
| Kha-nae | 14,394 / 1.20 m | 19 bones, four clips, player work layers and separate tools |
| Ta-poh | 19,900 / 1.15 m | 19 bones, four clips, separate clearing blade / borrowed sprayer |
| Mu-naw | 13,957 / 1.10 m | 21 bones, four clips, dress controls and independent suppression gear |
| Mae-Lu | 19,900 / provisional 1.15 m | 21 bones, six clips, village granary portrait/gesture |

Installed assets and checksums: `artifacts/character_rigs_v31/installation.json`.
Rollback copies of the previous three models/scenes are in its `rollback/`.
All reviewed source triangles, UVs and textures are preserved. No failed build
was installed; rejected trials and failure coordinates remain in the build logs.

Passed: exported clips/grounding, four-angle work previews, real-renderer work
and locomotion deformation, slope/cough samples, skin/material checks, actual
controller motion and water accounting, ordered douse, interruptions, satellite
stop, full gameplay suite, village portrait gesture and 120-frame smoke run.
The motion reel is an in-place preview, not a navigation recording.

Remaining limitations: documentary clothing/likeness evidence, fingers/facial
animation, deep crouches, large terrace contact and further stride polish. This
is a tested gameplay rig installation, not a claim of perfect animation or
culturally authenticated costume details.

## Research limitations to resolve

The direction names real human inspirations but supplies generated design sheets,
not the standalone Dawjai portrait/clothing photograph mentioned in its text.
The atlas records this honestly. Primary interviews support the human/community
roles, not every textile, accessory or claimed motif in the concept sheets.
Mae-Lu's inspiration is from Huai I Khang; Ta-poh's source refers to Nong Tao;
Kha-nae's interview discusses Samoeng. Do not collapse these into one locality.

The community's [2026 firebreak account](https://www.hinladnai.com/2026/03/28/%E0%B9%81%E0%B8%99%E0%B8%A7%E0%B8%81%E0%B8%B1%E0%B8%99%E0%B9%84%E0%B8%9F/)
supports practical blades, rakes/brooms, brushcutters and blowers, shared work
and careful travel on steep ridges. It does not establish the concept's brass
sprayer or white dress as the local forest-work uniform.

## Pipeline findings

- Blind low-poly decimation distorts UV texture. The new `rebake_lowpoly.py`
  uses fresh UVs and CPU source-color baking; the Mu-naw experiment restored
  garment bands. It still requires visual review, especially small facial planes.
- `run_refined_character.py` supports generation-step/seed experiments and
  records actual cache provenance. Four runner tests currently pass.
- Static previews now use an isolated Godot project; concurrent gameplay/audio
  edits cannot contaminate model-only rendering. Actual gameplay validation
  still uses the full project and remains mandatory before installation.

## Latest quality findings

- All four selected repaired candidates exist, but none is declared production-ready.
- Mu-naw v02 fresh texturing was interrupted by a separate Ollama workload. The
  runner correctly refused insufficient VRAM, then a queued cache reuse succeeded
  when memory became available. No other workload was stopped.
- Source surfaces have many tunnels even when their triangle boundaries are closed.
  “Watertight” is not the same as a solid human surface with no accidental tunnels.
  A ray through Kha-nae's rear scarf reached the front face. Texture painting cannot
  repair that defect. Candidate-only cloth patches demonstrate the diagnosis.
- `artifacts/cast_v31_20261002/closing_probe.log` compares 256/512 grids and closing
  strengths. More closing iterations did not consistently improve topology.
  `solidify_probe.log` records the next solid-volume experiment; it is not yet an
  approved default or proof that fingers/hair gaps are preserved.
- `in_game_v3/` has actual terrain/lighting captures, including 22 m and 44 m camera
  distances. These are explicitly static candidates, not installed/animated models.
- Regressions passed: four runner checks; closed-shell reconstruction at both grids;
  real CPU texture rebake colour correspondence; small-hole versus large-opening
  repair. Headless120 smoke exits successfully with an existing ObjectDB leak warning.
- Final cultural lock remains open. See each atlas's `06_notes/production_gate.md`.
  Do not start Mu-naw's final rig calibration while that explicit v3.1 gate is open.

## Outer-surface reconstruction experiment

The original TRELLIS Mu-naw mesh also has the neck/sleeve/hem defects, so the
problem precedes the sparse-voxel cleanup. Sampling only visible, front-facing
surfaces from 26 directions and reconstructing those oriented points with screened
Poisson reduces hidden walls and accidental tunnels. This is still candidate-only.

- Mu-naw: depth 8 yields one watertight component with Euler characteristic -14;
  depth 7 yields one with Euler characteristic 0. The latter is much cleaner, but
  these numbers alone cannot certify the shape or distinguish intentional openings.
- Kha-nae: a reconstruction plus the separate faceted bamboo hat removes the
  conspicuous rear-wrap tunnel in the four-angle render.
- Ta-poh and Mae-Lu: repaired candidates exist in `outer_cast/`; texture artifacts
  remain. Merely transferring colour from a damaged source carries those marks over.
- Fresh texturing on all four repaired meshes is complete. Kha-nae and Mu-naw
  preserve facial colour from their preferred clean masters; Ta-poh and Mae-Lu
  use the reviewed new texture. Copying a damaged reduced bake was rejected.

Evidence and complete experiment scripts live under
`artifacts/cast_v31_20261002/`. PyMeshLab 2025.7.post1 was installed into the isolated
remote experiment directory `cast_v31_tests/meshlibs`, not the game's dependencies.
The shared review project's renderer is now explicitly using the default Forward+
path; its earlier compatibility configuration must not be used as final acceptance.

## Reference follow-up

The earlier wait-before-rigging gate was explicitly superseded by the user's
instruction to proceed. The standalone portrait and clothing photographs remain
missing. When supplied, compare them against the current cast and record any
changes needed; regenerate/recalibrate only affected geometry and keep source
hash guards. Do not reuse the old Mu-naw locked-carry/offset profile.

Earlier generation/outer-surface tests remain in `artifacts/cast_v31_20261002/`.
Their static reports are historical inputs, while `artifacts/character_rigs_v31/`
records this completed gameplay rig installation and its remaining limitations.
