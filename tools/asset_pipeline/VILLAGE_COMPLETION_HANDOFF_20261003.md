# Village and asset completion — 2026-10-03

Delivered in the local game following the user's “do it all” authorization. This includes runtime placements and presentation hooks, superseding the earlier asset-only restriction for this work. No release, deployment or Git push was performed.

## Installed behavior

- The Village Hearth now renders the approved four characters, both S4 houses, S3 granary and S8–S16 props in a 3D night scene. “ดูหมู่บ้าน” opens a larger inspection view with village/radio/granary/workshop buttons; closing restores the management screen. Existing radio, ration, repair, exchange and launch mechanics remain connected.
- Rice sacks reflect current reserves (ceil(rice_barn / 20), capped at five), without changing resource accounting. The normal granary stays closed; the famine ending uses S11's open, empty interior.
- Hearth cards adapt to narrow windows; the launch button remains visible at 1280×720, 960×720 and 1280×600. Both houses and the granary fit the overview camera.
- Ta-poh's borrowed sprayer now has a live hose from tank to wand, following animation/movement and wand visibility. The separate bamboo tank outlet is local (-0.11, -0.10, -0.04) m; T4 uses (0.15, 0.055, -0.09675) m. Disable/reconfigure removes the hose. Wand mounting accounts for actor scale. Existing belt knife and player rake correction are retained.
- Thermal camera status indicator reduced to radius 0.025 m, height 0.05 m, at actor-local (0.145, 2.735, 0.255). Detection logic unchanged.
- Famine S11 scene placement: (3.4, 0, -1.4), yaw PI + 0.32. Its empty doorway faces the ending camera. Props remain base-centred; placements are scene transforms.

## Static delivery

The installed inventory is 56 static GLBs across 36 manifest IDs. This pass promotes S8–S11 from the future source archive and adds S12–S16. S4's previously delivered variants now have live village placements. Dimensions below are X × Y × Z in metres; exact inventory, hashes and bounds are in `artifacts/village_completion_20261003/installed_prop_inventory.json`.

| ID | File | Triangles / ceiling | Dimensions (m) |
|---|---|---:|---|
| S10 | S10_rice_basket_a.glb | 1304 / 1500 | 0.708 × 0.600 × 0.709 |
| S11 | S11_empty_granary_a.glb | 5880 / 6000 | 2.350 × 3.000 × 4.317 |
| S12 | S12_rice_sack_a.glb | 1228 / 1500 | 0.426 × 0.550 × 0.267 |
| S13 | S13_timber_stool_a.glb | 1347 / 1500 | 0.377 × 0.400 × 0.301 |
| S14 | S14_firewood_bundle_a.glb | 1470 / 1500 | 0.650 × 0.313 × 0.518 |
| S15 | S15_lidded_grain_basket_a.glb | 1392 / 1800 | 0.716 × 0.650 × 0.718 |
| S16 | S16_repair_supplies_a.glb | 264 / 500 | 0.250 × 0.062 × 0.180 |
| S8 | S8_transistor_radio_a.glb | 975 / 1500 | 0.350 × 0.268 × 0.153 |
| S9 | S9_repair_workbench_a.glb | 2729 / 3000 | 1.400 × 0.851 × 0.696 |

All deliveries use grounded bases and the +Z front contract. S16 is width-fitted to 0.25 m (height 0.062 m), avoiding the rejected oversized height-fit version. Radio and repair tray mount on the bench at local Y=0.741 m; radio X=-0.38, Z=0.03; repair tray X=0, Z=-0.03. Basket S10's interior floor is approximately Y=0.045 m. E7 terrace endpoints and E9's ≤40-triangle budget are unchanged.

S12–S14 use Meshy geometry with local cleanup, decimation and authored matte materials. Their pale provider textures were rejected; final tan cloth, brown wood, muted rope and light cut ends are broad colour areas. S15 combines the previously reviewed basket with a locally authored lid/handle; S16 is a locally authored repair tray with seals and a stone. Neither local item costs Meshy credits.

Reference work remains in `KAREN_PROP_REFERENCE_BRIEF_20261003.md`. SAC material informed grain storage context: https://www.sac.or.th/portal/th/article/detail/664 and https://wikicommunity.sac.or.th/community/1335 . Plain sacks/stools/firewood are game adaptations, not claimed uniquely Karen designs. Basket references are geographically specific; community cultural review remains pending. Do not equate technical approval with cultural certification.

## Character motion

Six installed GLBs retain the approved faces, outfits, geometry, materials, skin weights, roots, limbs and other clips:

| Character | Changed clips |
|---|---|
| Kha-nae | Idle |
| Ta-poh | Idle |
| Mu-naw | Idle |
| Mae-Lu | Idle, Talk |
| Ranger, olive and slate | Scan |

Meshy local first-frame-relative chest/head rotations are transferred through source bind axes at gain 0.15, with a 12° output guard. Approved limb/tool-contact tracks stay in place. This is a restrained torso/head overlay, not a full-body gait, finger or facial-animation converter. Kha-nae reuses the prior paid pilot; both ranger palettes reuse one Scan source.

The initial full-body retarget was rejected for excessive deformation (over 5× edge stretch). The accepted helper `tools/character_pipeline/retarget_meshy_overlay.py` supports Idle/Talk/Scan only. A reproduction from Kha-nae's rollback GLB matches the installed candidate SHA exactly. `character_install.json` records old/new SHA and preservation checks; rollback files are under `artifacts/village_completion_20261003/rollback/characters/`.

Reproduce a candidate with Blender (use a fresh output and the approved baseline):

```sh
/Volumes/Blender/Blender.app/Contents/MacOS/Blender -b --python-exit-code 1 \
  --python tools/character_pipeline/retarget_meshy_overlay.py -- \
  --source provider_motion.glb --target approved_game.glb \
  --output candidate.glb --clip Idle --duration 2.4
```

Validate all named clips with the project renderer, not headless skin baking:

```sh
godot --path . --script tools/character_pipeline/check_candidate_clips.gd -- \
  artifacts/village_completion_20261003/final_contract_manifest.json \
  artifacts/village_completion_20261003/all_clip_deformation.json
```

Also run the contract checks, `tests/test_v31_candidates.gd` on normal and slope profiles, equipment and gameplay motion tests before installation. SOP and Meshy setup now document this route.

## Credits and provenance

Starting balance 1113; spent **105**; verified remaining **1008**. Self-imposed ceiling was 300. Three mesh+refine jobs cost 90 total; five animation jobs cost 15. No GPU-node jobs ran. Prior expansion costs are separate.

| Asset | Stage | Provider task ID | Credits |
|---|---|---|---:|
| S12 | mesh | `01a0fff4-c435-70c4-abdb-185ac598103a` | 20 |
| S12 | texture | `01a0fff7-e188-7278-811e-bc7151dbe1f1` | 10 |
| S13 | mesh | `01a0fff4-cf7d-7207-bcca-60f4af99fd0f` | 20 |
| S13 | texture | `01a0fff7-ea3e-710b-9447-6b995f10c8bb` | 10 |
| S14 | mesh | `01a0fff4-da7a-7431-89c0-a69da0e229bc` | 20 |
| S14 | texture | `01a0fff7-eb51-7620-97c1-0b7495e285c7` | 10 |
| tapoh | animation | `01a0ffff-e720-77c7-834e-e92f04660deb` | 3 |
| munaw | animation | `01a0ffff-e9c6-73b2-8bd4-308d29dd276e` | 3 |
| maelu | animation | `01a0ffff-ec67-75e1-ab46-05c623278976` | 3 |
| maelu_talk | animation | `01a0ffff-eeb1-745a-80a6-4f658481527c` | 3 |
| ranger_scan | animation | `01a0ffff-f0fb-773a-829e-3b2a6561aa7a` | 3 |

The evidence directory retains submissions/prompts, provider statuses, raw GLBs, candidate reviews, rejected transfers, install records and `credit_ledger.json`. Signed download URLs are transient provenance, not credentials to copy into published documentation.

## Verification and visual evidence

All paths below are relative to `artifacts/village_completion_20261003/`:

- `test_all_batch1.log`, `test_all_batch2.log`, `test_all_final.log`: complete game suite after each install batch, **0 failures**, including the final famine placement.
- `props_final.log`: all 56 static GLBs pass triangle, scale and material validation.
- `final_contract.json`: six character contracts pass.
- `all_clip_deformation.json`: six files/all named clips sampled through endpoints; worst edge stretch ≤3.5 without relaxing the threshold. Largest observed value 3.393 (Mu-naw ToolUse).
- `final_character_deformation.json` and `final_slope_deformation.json`: runtime work, slope and cough layering pass.
- `equipment_final.log`, `gameplay_motion_final.log`, `ranger_final.log`: equipment mounting, moving hose, rake clearance, actual dousing, interruptions and both ranger palettes pass.
- `village_final.log`: props, four characters, reserve updates, responsive framing, inspection reparent/restore and radio controls pass.
- `village_final_views/village_overview.png`, `village_S8.png`, `village_S9.png`, `village_S3.png`: installed village and station views.
- `hearth_final/hearth.png`, `hearth_4x3.png`: management UI review.
- `famine_installed/famine.png`: installed empty-granary ending.
- `surveillance/camera_45.png`: reduced status indicator.
- `all_motion_review.png`: multi-angle character review; exact tool-contact acceptance comes from equipment/gameplay checks, not its static prop preview.
- `S12_final_candidate/preview.png`, `S13_final_candidate/preview.png`, `S14_final_candidate/preview.png`, `S15_candidate/preview.png`, `S16_final_candidate/preview.png`: reviewed final props.

Godot reports ObjectDB/resource leaks at process exit in some checks, despite successful exit and zero test failures; these are not resolved by this asset pass. No Steam Deck/low-end performance measurement or native cultural/Thai-text signoff was completed. Local renderer evidence comes from this Mac. Newly installed content requires a new build before public downloads contain it.
