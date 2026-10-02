# v1.1 asset delivery — 2026-10-02

Scope: CHAR assets for PRD_UPDATE_v1.1. No patrol, ending, UI, audio-manager,
controller, reach or balance implementation is included in this asset pass.

## Reviewed props

All are metre-scale, base-centred, +Y up, +Z front, matte faceted vertex-colour
GLBs. Source generator: `gpu/build_v11_props.py`; palette: `palette.json`.
Four-angle review: `artifacts/asset_update_v11/props_v3.png`. Actual game-lighting
review: `artifacts/asset_update_v11/world_review_v3/` at 12/22/44 m. Props were
staged temporarily in a cleared patch for review; this is not ending integration.

| ID | Production path | Triangles | Notes for GAME |
|---|---|---:|---|
| T2 | `assets/props/T2_mida_knife_a.glb` | 68 | 0.5 m; grip centre approximately local (0, 0.07, 0). Offset by -0.07 Y when attaching at a hand socket. Blade points +Y. |
| S3 | `assets/props/S3_granary_a.glb` | 516 | 3 m; raised granary with open doorway, no grain. Place on level ground; generic concept, not a verified locality-specific building. |
| S5 | `assets/props/S5_checkpoint_a.glb` | 316 | 3 m wide; unmarked barrier, blank sign and sandbags. Static combined mesh, no moving barrier rig. |
| S6 | `assets/props/S6_ranger_truck_a.glb` | 380 | 1.96 m wide, unmarked pickup. Static wheels; animate the vehicle root. Add lights in the ending scene. |
| S7 | `assets/props/S7_travel_bundle_a.glb` | 96 | 0.46 m; tied indigo cloth. Rejected earlier variants had floating straps. |
| T6 | `assets/props/T6_ranger_flashlight_a.glb` | 104 | 0.224 m, grip around local Y 0.08; beam exits +Y, lens at Y 0.224. GAME adds SpotLight3D. |
| T7 | `assets/props/T7_ranger_tablet_a.glb` | 24 | 0.20 × 0.14 m; blank screen on +Z, centre at local Y 0.07. |

Use `AssetLibrary.mesh_or(ID, fallback)` for static prop meshes. If loading with
GLTFDocument directly, use `AssetLibrary._append_meshes` or enable vertex colours
on each material; raw runtime imports can otherwise appear white. Do not flatten
the Ranger rig through AssetLibrary.

## C5 Ranger delivery

- `assets/models/ranger_rigged.glb`: olive uniform.
- `assets/models/ranger_slate_rigged.glb`: cold grey-green texture variant.
- `scenes/characters/RangerChibi.tscn` and `RangerSlateChibi.tscn`: ready-to-instance
  asset scenes, with `RangerRig.gd` for clip playback and hand props.
- Each is 1.25 m, 19,800 triangles, 19 bones, matte 2K albedo. No real insignia,
  flags, names or weapons. Both variants share byte-identical geometry, skin and
  animation data; only the albedo image differs.
- Clips: Idle 2.4 s; Walk 0.8; Run 0.666667; Scan 3.2; Photograph 2.0;
  Point 1.6; RadioTalk 2.4; Escort 0.933333. In-place motion, +Z forward.
- `update_animation(delta, velocity, face)` provides the existing RangerFigure
  locomotion contract. GAME already orients/moves its root; the asset does not
  create patrol rules. `play_clip("Photograph")`, `play_clip("RadioTalk")`, etc.
  select authored gestures. Right hand holds the tablet, left hand the flashlight.
  A supplied `Flashlight` SpotLight3D is attached to the physical lens in `_ready`.
- Existing `RangerFigure.create()` now resolves the production scene automatically
  for patrols and endings. Existing S5 lookup likewise resolves the checkpoint.
  GAME still needs explicit Scan/Photograph/RadioTalk/Point/Escort event calls and
  can choose the slate scene for a second ranger.
- Evidence: `ranger_equipment_final.png`, `ranger_variants_final.png`, rig build 15,
  `rig_check_final_report.json` (olive) and `variant_preserved_report.json` (slate),
  all under `artifacts/asset_update_v11/`. Both final variants passed all eight
  sampled Godot clips; worst edge ratio 3.419 (limit 3.5), ground error <0.75 mm.
- Limits: open-hand ordering gesture, no finger bones; close-up grip/contact and
  gait polish remain. The 19-bone asset does not implement an actor-to-actor escort
  constraint. Small baked cloth marks remain, but no open surface holes were accepted.

## UI art and audio

Portraits in `assets/ui/portraits/` are transparent 256 × 256 renders of the
actual installed rigs, not newly generated faces. Kha-nae, Ta-poh, Mu-naw,
Mae-Lu and Ranger are available.
`tools/character_pipeline/render_portraits.gd` is the reproducible renderer.

Title artwork: `assets/ui/title/satellite_shadow_blue_hour_1920x1080.png`.
Faceted blue-hour hillside, crew at lower right, satellite streak, no baked text.
The generator's 1672 × 941 original is preserved as `satellite_shadow_blue_hour_v01.png`;
the production file is a 1920 × 1080 canvas export through Godot
(`export_title_canvas.gd`). GAME owns title placement and the README image.

Four A2 spoken candidates are in `assets/audio/v11_candidates/`: Mu-naw's
spot-fire/out calls, Ta-poh's whistle reply and a Ranger patrol report. They are
24 kHz mono PCM16. Whisper transcription matched each intended Thai line (CER 0).
This does not certify acting, speaker consistency or pronunciation: listening
review is pending. Mu-naw/Ranger use designed OmniVoice-Thai voices; Ta-poh uses
the existing A1 Pop reference. The generator is `tools/tts/gen_v11_barks.py`.
Five deterministic synthetic cough candidates are also supplied, derived from the existing AudioManager cough with character-specific pitch/seed. They are not human recordings and still need listening review; preserve procedural fallbacks.
Do not replace AudioManager's existing A3 radio catalogue with these files.

## Integration remaining with GAME

GAME has since implemented endings, patrols and checkpoint scenes. This pass supplies
their asset resources, not those features. Remaining hooks: S3/S6/S7 ending prop
placement, T2 on Kha-nae's belt/off hand, authored Ranger action events/second palette,
U3 HUD/radio portraits, U6 title/README placement and A2 playback after listening
review. Optional P2 assets are not represented as complete here.


Final inspection: `artifacts/asset_update_v11/world_review_final/assets_12m.png`
shows the delivered models together in current game lighting. The full test suite
reports zero failures. Its corrupt-save negative test intentionally emits a JSON
parse error, and the existing two ObjectDB leaks remain at exit; the separate
asset contract and 120-frame smoke logs are clean.
