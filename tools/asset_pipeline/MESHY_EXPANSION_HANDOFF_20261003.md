# Meshy expansion delivery — 2026-10-03

Completed under the user's 250-credit approval. Spent **213**, verified balance
**1,113** (start 1,326). Seven textured Meshy-7 GLB jobs cost 30 each; one Idle
pilot cost 3. No paid retries/remeshes, further animation jobs or GPU jobs.
The unused 37-credit allowance remains unspent.

Evidence root, relative to the repository:
`artifacts/meshy_expansion_20261003/` (R below). Cost/task record:
`R/credit_ledger.json`, `R/provider_tasks.json`, `R/approval.json`.
Raw GLBs, concepts, exact submission parameters, local repair scripts and
candidate build logs remain there. Signed provider URLs are private evidence,
not shipping documentation. Production delivery remains GLB, Y up, +Z front,
grounded Y=0 and centred on X/Z. All listed counts are final triangle counts.

## Installed current assets

| ID | Installed file in assets/props | Triangles / ceiling | Dimensions X × Y × Z, metres | Review images under R |
|---|---|---:|---|---|
| V3 | V3_satellite_a.glb | 3,919 / 4,000 | 2.000 × .710249 × .382868 | V3_candidate/preview.png; title/title.png |
| V1 | V1_drone_a.glb | 1,809 / 3,000 | 1.200 × .263 × 1.200 | V1_final_candidate/preview.png; composite_final/drone_{0,45,90}.png |
| V2 | V2_thermal_camera_housing_a.glb | 1,198 / 1,500 | .420 × .228069 × .500 | V2_final_candidate/preview.png; composite_final/camera_{0,45,90}.png |
| S5 | S5_checkpoint_a.glb | 2,570 / 3,000 | 3.000 × 1.016548 × .995371 | S5_candidate/preview.png; checkpoint_installed/{checkpoint,checkpoint_open}.png |

V3 reused the accepted satellite. Local decimation and fitting corrected the
previous 5,335-triangle, scale and grounding violations, preserving two symmetric
X wings, +Z flight and -Y scanning. The existing runtime bounding-box centre
and title staging still apply. Original rollback: `R/rollback/V3_satellite_a.glb`.

V1 keeps the Meshy fuselage, camera and UVs. The provider invented static blades;
those and stray blade fragments were removed locally. Motors were aligned and
four solid 12-sided caps added at X/Z ±.48 m. Front required a -90° yaw.
Final body has one textured and one solid surface. The existing controller places
its procedural rotor discs at mesh top +.015 m, now Y=.278, with 15 mm cap
clearance. Existing drone-body actor offset (0,-.15,0) is unchanged. Review uses
actual ForestryDrone rotors, rather than substituting new rotation behaviour.
`R/composite_final/mounts.json` records positions.

V2 was widened from .24778 to .420 m along X to fit the existing warning-light
assembly better; maximum X/Z span remains the specified .5 m. Meshy texture was
replaced locally by three broad matte materials (grey housing, charcoal lens,
muted red centre), preserving the faceted mesh. Housing actor base remains
Y=2.58; separate runtime warning sphere stays at (0,2.7,.26). **GAME follow-up:**
the current .09 m radius bright sphere obscures part of the new lens. Reduce or
reposition that indicator if the intended look is a small status lamp. Asset work
does not claim to fix that runtime geometry.

S5 supplies posts, bases, sandbags and blank sign dressing, with **no static
crossbar**. The existing UI supplies the moving arm. Its position (4.2,0,-.4)
and -90° yaw remain unchanged. Closed and raised barrier states were inspected
using fixed 1/60 s stepping. An earlier candidate review used a large timestep
and overshot the UI's interpolation; only `checkpoint_installed/` and
`checkpoint_candidate_final/` are final evidence.

All four replacements passed quality budgets, finite geometry/material checks,
centring, grounding and visual review. Installation tools saved per-candidate
rollback records. Required full tests passed after both installed batches:

- `R/test_all_V3.log`: RESULT: OK (0 failures).
- `R/test_all_surveillance.log`: RESULT: OK (0 failures).
- `R/installed_validation.log`: all **47** installed props pass quality validation.

JSON parse errors in the full test logs are expected corrupt-save/record fixtures;
the associated rejection/fallback tests pass. They are not new asset failures.

## Future library — delivered, not registered or placed

Stable delivery: `tools/asset_pipeline/future_library/`, excluded from Godot
resource scanning by `.gdignore`. Contracts are reserved in
`future_asset_manifest.json`; these IDs are not in the production manifest.
`delivery.json` contains final bounds, material counts and SHA256 hashes.

| ID | File | Triangles / ceiling | Dimensions X × Y × Z, metres | Review images in future_library |
|---|---|---:|---|---|
| S8 | S8_transistor_radio_a.glb | 975 / 1,500 | .350 × .267576 × .153087 | S8_review.png |
| S9 | S9_repair_workbench_a.glb | 2,729 / 3,000 | 1.400 × .850864 × .695824 | S9_review.png |
| S10 | S10_rice_basket_a.glb | 1,304 / 1,500 | .707953 × .600 × .709392 | S10_review.png; S10_interior_review.png |
| S11 | S11_empty_granary_a.glb | 5,880 / 6,000 | 2.350318 × 3.000 × 4.316702 | S11_review.png |

S8 has a blank dial, chunky handle and no brand lettering. S9 is a plain timber
repair bench with seal tray/stone/rag; no handheld tool socket is promised.
Both use embedded albedo, restrained materials and flat facets.

S10 uses a tapered plain bamboo-storage form documented by the Wale local
administration in Tak. The PDF identifies Pgakenyaw craftspeople; this is a
local example, **not a universal Karen design**. Rice use is a game adaptation,
not a claim that this is a calibrated measuring vessel. No sacred imagery or
invented decorative ethnic motifs were added. Source and inspected page numbers:
`future_library/BASKET_REFERENCE.md`; cultural/community review is still needed
before production use. Source photos are research evidence, not shipping textures.
The provider's shallow interior cap and residual fragments were removed locally;
a matte inner wall and floor were authored. Five downward rays in the delivered
GLB hit Y=.045 beneath a .600 m rim (`S10_depth_check.json`), confirming actual
hollow geometry. Final local candidate is `R/S10_clean_candidate/`; earlier
S10 candidates are superseded.

S11 is a separately generated S3-family design, not a byte-identical S3 variant.
The front needed -90° yaw. The provider supplied a closed door; it was cut out
locally, with an outward-open wooden leaf and bare floor/back/side walls added.
Raw doorway width .68 m, floor Y=1.26, top Y=2.15. Final ground-centring includes
the open leaf, so GAME must derive placement/interaction offsets from the final
mesh, not copy S3's doorway centre. The broad depth includes its access ladder
and open door. Current S3 remains installed; GAME must choose the famine hook.
Natural roofing is the established game adaptation, not a claim to duplicate a
specific contemporary rice-bank photograph. See the existing cultural reference
brief for the building source distinctions.

Future-prop gameplay-distance staging at 12/22/44 m is in
`future_library/distance_{12,22,44}m.png`, source `R/future_distance/`.
This is temporary staging in Main lighting, **not gameplay integration**.
Small radio details disappear at wide camera distances; a close Hearth view or
UI interaction will be needed. The distance-review harness emits an exit-only
ObjectDB leak warning; snapshots are complete, and full installed-game tests pass.

## Animation pilot — rejected, approved cast preserved

Kha-nae native-rig Idle (action 0) was generated successfully for 3 credits,
but the experimental transfer to the existing game skeleton failed the gameplay
rake deformation test: worst edge stretch **5.403669**, limit **3.5**, at zero
velocity/frame 18. Visual idle stance was also unsuitable. Contract preservation
alone was insufficient. The candidate was **not installed**; the other five
planned motion jobs were **not submitted**.

Evidence: `R/animation_pilot/decision.json`, `R/pilot_deformation.json`,
`R/pilot_contract.json`, `R/pilot_review.png`. Experimental retarget source stays
under R, not as an accepted production tool. All six installed rigged character
SHA256 hashes match the pre-work baseline (`R/character_preservation_check.json`).
No approved likeness, outfit, equipment socket or existing animation changed.

## Provider task IDs

| ID | Meshy task | Credits |
|---|---|---:|
| V1 | 01a0ffd5-dce2-72df-a912-f5ef3e041637 | 30 |
| V2 | 01a0ffd5-ebfc-7395-b0f6-21f15c0d34ef | 30 |
| S5 | 01a0ffd5-f2aa-7238-b6df-c361a7b3b8ff | 30 |
| S8 | 01a0ffde-8924-741e-8301-386691932a14 | 30 |
| S9 | 01a0ffde-9987-75d9-9ce9-f443d7b85658 | 30 |
| S10 | 01a0ffde-a0a9-710e-9a39-c9473bf1f84e | 30 |
| S11 | 01a0ffde-aeed-74b2-9c22-1e366fa5a326 | 30 |
| Idle pilot | 01a0ffd2-ca51-75df-8905-231fd7e45ec6 | 3 |

No edits to `scripts/`, `ui/` or `tests/test_all.gd` were made by this pass.
No release build or website download was changed. Further integration/animation
work should use the limits above rather than assuming provider success is approval.

## Subsequent integration

The later user-authorized completion pass installed the village placements, promoted S8–S11 and added S12–S16 and compatible character motion. See [completion handoff](VILLAGE_COMPLETION_HANDOFF_20261003.md) for current installed state and the separate 105-credit ledger. Earlier unchanged-character/source-only statements describe the prior batch.
