# Satellite Shadow — Asset List

Characters now use textured generated models, with calibrated skeletal rigs for all four v3.1 crew characters. Props have procedural fallbacks in `scripts/LowPoly.gd`; reviewed generated props can replace them. Particles and UI come from `FireGrid.gd` / `HUD.gd`, and audio from `scripts/AudioManager.gd`. This list tracks asset roles and routes; current build settings are in each pipeline's manifest.

**2026-10-02 polish installed:** 19 revised props plus new flame/mist/ash textures.
The approved six rigged character files are unchanged. Current counts, offsets,
review images and remaining GAME integration work are recorded in
[the polish handoff](tools/asset_pipeline/ASSET_POLISH_HANDOFF_20261002.md).

**Building a 3D prop:** `./tools/asset_pipeline/build_asset.sh <ID> --prompt` prints a reference prompt. `--image <png>` or `--mesh <glb>` creates an isolated review candidate. After visual review, `install_asset.py <candidate-dir> --reviewed` validates and installs it. See `tools/asset_pipeline/README.md`.

**Routes**
- **IMG→3D**: TRELLIS.2 for textured quality props, TripoSR for standard vertex-colour props. Thin handles, culms and open structures need special review; procedural modelling is often more reliable for those parts.
- **PROC**: keep it procedural, or model it by hand or with a Blender script. Best for thin or repeating geometry.
- **IMG2D**: 2D image generation (ComfyUI on gpu01) plus background removal, exported as PNG with alpha.
- **AUDIO**: recording, a CC0 library, or TTS (OmniVoice-Thai on gpu01). For music, use ACE-Step (MIT), not MusicGen (CC-BY-NC; see the licence note in project memory).

**3D spec (all models)**
- **Required art direction:** stylized low-poly, simple angular silhouettes, visible faceted shading, broad colour areas and restrained painted textures. Characters, props and terrain must look consistent at gameplay distance. Preserve cultural patterns in simplified form; reject photorealistic materials, dense surface noise and glossy realism. See PRD §9.1.
- Both standard and quality routes follow this same style. Quality budgets are ceilings, not detail targets. Visual review must compare the candidate with the existing game scene before installation.
- glTF `.glb`, 1 unit = 1 m, +Y up.
- Origin at the base centre (y = 0 is the ground). The front faces +Z.
- Instanced vegetation: one vertex-colour surface. Prominent props: preserve UV textures and solid materials, at most eight surfaces.
- Triangle budgets matter: brush, bamboo and pines are instanced up to about 1,600 times per plot.
- Prop tables below retain standard budgets. Explicit quality budgets (for example S1: 6,000 triangles) are in `asset_manifest.json`; they do not raise vegetation budgets.

**Current installed coverage — 2026-10-03:** 56 static GLBs cover all 36
production manifest IDs, plus six rigged character GLBs and matching portraits.
The two S4 houses and S8–S16 village props are now placed in the live 3D Hearth;
S11 supplies the famine granary. The historical tables below contain earlier
budgets/counts; current exact values and contracts are authoritative in
`tools/asset_pipeline/asset_manifest.json` and
[the village completion handoff](tools/asset_pipeline/VILLAGE_COMPLETION_HANDOFF_20261003.md).

## 1. Characters (already in the character pipeline)

| ID | Asset | Size | Tris | Route | Status / notes |
|---|---|---|---|---|---|
| C1 | Kha-nae (player) | 1.20 m | 19,798 | Meshy | User-reference correction installed; 19 bones, 4 clips; existing tool sockets |
| C2 | Ta-poh (elder) | 1.15 m | 19,374 | Meshy | Installed; 19 bones, 4 clips; blade and borrowed sprayer |
| C3 | Mu-naw (young forest guardian) | 1.10 m | 19,541 | Meshy | Installed; 21 bones, 4 clips; skirt controls and separate sprayer |
| C4 | Crew rigs + animations | — | — | Meshy landmarks + calibrated Blender skin/clips | Four main characters retain Idle/Walk/Run/ToolUse and semantic runtime work layers |
| C5 | Fictional forest ranger | 1.25 m | 18,522 each | Meshy | Olive/slate variants installed; 19 bones, eight clips, existing flashlight/tablet hooks |
| C6 | Walking villagers (man, woman, elder, teenager) | ~1.15 m | 2,785 / 2,784 / 2,785 / 2,786 | Meshy | Four static walking poses installed; no rigs, existing S7 bundle attachment |
| C7 | Mae-Lu (headwoman / granary keeper) | 1.15 m | 19,436 | Meshy | Installed; 21 bones, 6 clips including Talk/Granary, live village portrait |

Five 256×256 transparent portraits match the installed models. All characters
retain the approved v3.1 direction and low-poly style. See
[Meshy cast handoff](tools/character_pipeline/MESHY_CAST_HANDOFF.md) for source
jobs, reviews, tests, limits and rollback. Meshy is used for characters and selected prominent props. Efficient procedural
vegetation, tiny fittings and local material/geometry repairs remain appropriate.

## 2. Hillside environment

| ID | Asset | Size | Tris | Route | Used for |
|---|---|---|---|---|---|
| E1 | Pine tree (3 variants) | 4.2 m tall | ≤300 | PROC | Installed: 3 palette-matched GLBs, 260 triangles each; conservation-forest border |
| E2 | Bamboo clump (3 variants) | 3.3 m tall | ≤400 | PROC | Installed: 3 five-culm clumps with lance leaves, 360 triangles each; bamboo cover |
| E3 | Upland brush / fallow scrub (4 variants) | 0.8 m tall | ≤150 | PROC | Installed: 4 green/dry/mixed variants, 136 triangles each; most plot cells |
| E4 | Charred bamboo stump | 0.4 m | ≤80 | IMG→3D | Smoldering / ash cells (glow and charcoal tints are applied by the game) |
| E5 | Burnt brush root collar | 0.3 m | ≤80 | IMG→3D | Smoldering / ash cells |
| E6 | Rocks / boulders (4 variants) | 0.3–1.2 m | ≤150 | IMG→3D | New set dressing on terraces and the border |
| E7 | Terrace retaining wall segment (stone/earth) | 1.5 m wide | ≤150 | IMG→3D | New: edges of the stepped terraces (Plot 5) |
| E8 | Fallen log / dry branches | 1.5 m | ≤150 | IMG→3D | New set dressing |
| E9 | Grass / weed tufts (3 variants) | 0.3 m | ≤40 | PROC | New: ground detail |

## 3. Structures and props

| ID | Asset | Size | Tris | Route | Used for |
|---|---|---|---|---|---|
| S1 | Karen field hut on stilts, thatch roof | 3.3 m tall; installed bounds 3.11×3.49 m | ≤1,500 standard / ≤6,000 quality | IMG→3D | Crew spawn point; reviewed 5,845-triangle low-poly textured hut installed 2026-10-02 |
| S2 | Water barrels / bamboo water tubes | 0.9 m | ≤300 standard / ≤1,500 quality | PROC | Installed: two blue barrels and bamboo tubes, 464 triangles; sprayer refill point |
| S3 | Rice granary (ยุ้งข้าว) | 3 m | 516 | PROC | Installed v1.1 asset; empty interior, ending placement by GAME |
| S4 | Village house (2 variants) | 4 m | ≤2,000 | IMG→3D | Hearth backdrop |
| S5 | Unmarked checkpoint roadblock | 3 m wide | 316 | PROC | Installed v1.1 asset; Year 4+ scene by GAME |
| S6 | Unmarked ranger pickup | 1.96 m wide | 380 | PROC | Installed; crackdown ending prop, static wheels |
| S7 | Tied cloth travel bundle | 0.46 m | 96 | PROC | Installed; famine ending prop |

## 4. Surveillance

| ID | Asset | Size | Tris | Route | Used for |
|---|---|---|---|---|---|
| V1 | Forestry quadcopter drone | 1.2×0.37×1.2 m | ≤800 | PROC body; rotor discs stay in code | Installed: 428-triangle body and camera; separate rotors aligned to motor centers at X/Z ±0.48 m |
| V2 | Ground thermal camera post | 2.9 m pole + housing | ≤300 | PROC (pole) + IMG→3D (housing) | Year 3+ park-boundary cameras |
| V3 | Polar-orbit satellite | — | ≤1,000 | IMG→3D | Optional: 20:00 overpass cinematic |

## 5. Tools (held by the player)

| ID | Asset | Size | Tris | Route | Notes |
|---|---|---|---|---|---|
| T1 | Drip torch | 0.9 m | ≤200 | PROC | Grip at the origin; the flame tip glows in code |
| T2 | Mida knife | 0.5 m | 68 | PROC | Installed; grip local Y 0.07, belt/off-hand integration by GAME |
| T3 | Rake / hoe | 1.4 m | ≤200 | PROC | |
| T4 | Backpack sprayer tank (15 L) | 0.35×0.46×0.2 m | ≤300 | IMG→3D | Worn on the back |
| T5 | Sprayer wand + hose | 0.8 m | ≤150 | PROC | |
| T6 | Ranger flashlight | 0.224 m | 104 | PROC | Installed; separate hand prop, beam exits +Y |
| T7 | Ranger evidence tablet | 0.14 m high | 24 | PROC | Installed; blank screen +Z |

## 6. Visual effects (2D sprites, PNG with alpha)

| ID | Asset | Format | Route | Used for |
|---|---|---|---|---|
| X1 | Flame flipbook | 4×4 sheet, 512 px | IMG2D | Installed revised greyscale + alpha with broader cores; game supplies colour |
| X2 | Smoke puffs (4 variants) | 512 px 2×2 sheet | IMG2D | Installed white/grey + alpha; game supplies tint |
| X3 | Ember / spark | 64 px | IMG2D | Installed white-hot + alpha; game supplies tint |
| X4 | Steam burst | 4×4 sheet | IMG2D | Bamboo culm explosions |
| X5 | Water spray mist | Optional 2×2 sheet | IMG2D | Installed neutral 512px mist atlas; existing douse/steam hook |
| X6 | Ash flakes | 64 px | IMG2D | Installed neutral 64px flake; existing ash burst hook |

## 7. UI and 2D art

| ID | Asset | Format | Route | Used for |
|---|---|---|---|---|
| U1 | Tool icons: torch, knife, sprayer | 128 px | IMG2D | HUD tool slot |
| U2 | HUD icons: clock, wind arrow, hotspot, rice, scrutiny eye, breath, water drop | 64 px | IMG2D | Top and bottom bars |
| U3 | Crew + Ranger portraits | 256 px RGBA | Actual GLB renders | Five portraits delivered from the four crew and C5. HUD/radio integration by GAME |
| U4 | Hearth background painting (night hut, fire, radio) | 1920×1080 | IMG2D | Village Hearth screen |
| U5 | Hearth panel art: radio, granary, workbench, mutual aid | 512 px | IMG2D | Hearth panels |
| U6 | Blue-hour title artwork | Target 1920×1080 | IMG2D | 1920×1080 canvas export delivered, generated original preserved; GAME title/README placement pending. Text stays in UI |
| U7 | Font with Thai + emoji coverage (e.g. Noto Sans Thai / Sarabun, OFL) | .ttf | Download | Some emoji (🤝) currently don't render |

## 8. Audio (everything is synthesized today; real audio is an upgrade)

| ID | Asset | Route | Notes |
|---|---|---|---|
| A1 | Ta-poh wind warning, 2–3 Thai / S'gaw Karen lines | AUDIO (OmniVoice) | **Done** — 3 recorded variants `assets/audio/tapoh_wind_warning*.wav` (OmniVoice-Thai "Pop" on gpu01; manifest in `artifacts/tts_batch/`) |
| A2 | Crew barks: whistle reply, coughing, "embers!" | AUDIO (OmniVoice) | Four spoken candidates generated and ASR checked; five synthetic cough candidates added; listening review and GAME hooks pending. See v1.1 handoff |
| A3 | Ranger radio chatter (Thai) | AUDIO (TTS + radio filter) | **Done** — 8 decree/chatter lines `radio_ch1_*.wav` (FM 88.5) + 6 forecast lines `radio_ch2_*.wav` (FM 94.2); played over static through the band-limited `RadioVoice` bus |
| A4 | Bamboo culm PANG, fire crackle loop, water hiss | AUDIO (record / CC0) | |
| A5 | Drone rotor loop, siren loop, thunder | AUDIO (CC0) | |
| A6 | Forest ambience: cicadas, birds, wind in bamboo | AUDIO (CC0) | Synthesized wind + cicada beds now in `AudioManager.gd` (time-of-day fade, 18:00 inversion muffle); CC0 recordings remain an upgrade |
| A7 | Music: Tena harp + mouth organ, 3 intensity layers, 16 s loops | AUDIO (ACE-Step or commissioned) | Must loop seamlessly; layers fade in toward 20:00 |

## Priority (biggest visual gain first)

1. **C1–C4** characters (fix colours and orientation, then rig) · **E2** bamboo · **E3** brush · **E1** pine · **X1/X2** flame and smoke
2. **S1/S2** hut and barrels · **V1** drone · **E4/E5** stumps · **T1–T5** tools · **U1–U3** icons and portraits
3. **E6–E9** set dressing · **U4–U7** Hearth and title art · **A1–A7** audio · **S3–S5, V3** extras
