# Satellite Shadow — Asset List

Every in-game asset today is generated in code: props come from `scripts/LowPoly.gd`, and particles and UI come from `FireGrid.gd` / `HUD.gd`. All audio comes from `scripts/AudioManager.gd`. This list covers what real assets would replace, and which pipeline route fits each one.

**Building a 3D prop:** `./tools/asset_pipeline/build_asset.sh <ID> --prompt` prints the concept-image prompt. `--image <png>` builds the prop, and the game uses it automatically. See `tools/asset_pipeline/README.md`.

**Routes**
- **IMG→3D**: the existing character pipeline (`tools/character_pipeline/`, TripoSR on gpu01). Best for solid, chunky shapes. Poor for thin parts (handles, culms, needles), which come out as blobs.
- **PROC**: keep it procedural, or model it by hand or with a Blender script. Best for thin or repeating geometry.
- **IMG2D**: 2D image generation (ComfyUI on gpu01) plus background removal, exported as PNG with alpha.
- **AUDIO**: recording, a CC0 library, or TTS (OmniVoice-Thai on gpu01). For music, use ACE-Step (MIT), not MusicGen (CC-BY-NC; see the licence note in project memory).

**3D spec (all models)**
- glTF `.glb`, 1 unit = 1 m, +Y up.
- Origin at the base centre (y = 0 is the ground). The front faces +Z.
- Vertex colours rather than textures, flat-shaded.
- Triangle budgets matter: brush, bamboo and pines are instanced up to about 1,600 times per plot.

## 1. Characters (already in the character pipeline)

| ID | Asset | Size | Tris | Route | Status / notes |
|---|---|---|---|---|---|
| C1 | Kha-nae (player) | 1.2 m | ≤2,500 | IMG→3D | Model exists; colours washed out; no rig yet |
| C2 | Ta-poh (elder) | 1.15 m | ≤2,500 | IMG→3D | The hoe in the concept art fuses into the mesh |
| C3 | Mu-naw (youth) | 1.1 m | ≤2,500 | IMG→3D | The backpack and hose fuse into the mesh |
| C4 | Rig + animations: idle, walk, run, action (rake/torch/spray), cough | — | — | AccuRig / Mixamo (SOP step 4) | Not started. `ChibiAnimator.gd` fakes motion until then |

## 2. Hillside environment

| ID | Asset | Size | Tris | Route | Used for |
|---|---|---|---|---|---|
| E1 | Pine tree (3 variants) | 4.2 m tall, Ø 2.7 m | ≤300 | PROC | Conservation-forest border (300–600 instances) |
| E2 | Bamboo clump (3 variants) | 3.3 m tall, Ø 1 m | ≤400 | PROC | Bamboo cells; hides the crew from drones |
| E3 | Upland brush / fallow scrub (4 variants) | 0.8 m tall, Ø 1 m | ≤150 | IMG→3D or PROC | Most plot cells (up to 1,100 instances) |
| E4 | Charred bamboo stump | 0.4 m | ≤80 | IMG→3D | Smoldering / ash cells (glow and charcoal tints are applied by the game) |
| E5 | Burnt brush root collar | 0.3 m | ≤80 | IMG→3D | Smoldering / ash cells |
| E6 | Rocks / boulders (4 variants) | 0.3–1.2 m | ≤150 | IMG→3D | New set dressing on terraces and the border |
| E7 | Terrace retaining wall segment (stone/earth) | 1.5 m wide | ≤150 | IMG→3D | New: edges of the stepped terraces (Plot 5) |
| E8 | Fallen log / dry branches | 1.5 m | ≤150 | IMG→3D | New set dressing |
| E9 | Grass / weed tufts (3 variants) | 0.3 m | ≤40 | PROC | New: ground detail |

## 3. Structures and props

| ID | Asset | Size | Tris | Route | Used for |
|---|---|---|---|---|---|
| S1 | Karen field hut on stilts, thatch roof | 2.6×2.2 m footprint, 3.3 m tall | ≤1,500 | IMG→3D | Crew spawn point on the south edge |
| S2 | Water barrels / bamboo water tubes | 0.9 m | ≤300 | IMG→3D | Sprayer refill point by the hut |
| S3 | Rice granary (ยุ้งข้าว) | 3 m | ≤1,500 | IMG→3D | Hearth art / future 3D Hearth |
| S4 | Village house (2 variants) | 4 m | ≤2,000 | IMG→3D | Hearth backdrop |
| S5 | Military checkpoint roadblock | 3 m | ≤800 | IMG→3D | Year 4+ flavour (Hearth art / future cutscene) |

## 4. Surveillance

| ID | Asset | Size | Tris | Route | Used for |
|---|---|---|---|---|---|
| V1 | Forestry quadcopter drone | 1.2×0.3×1.2 m | ≤800 | IMG→3D (body); rotor discs stay in code | Drone patrols. Rotors spin in code, so keep them as separate meshes or leave them out |
| V2 | Ground thermal camera post | 2.9 m pole + housing | ≤300 | PROC (pole) + IMG→3D (housing) | Year 3+ park-boundary cameras |
| V3 | Polar-orbit satellite | — | ≤1,000 | IMG→3D | Optional: 20:00 overpass cinematic |

## 5. Tools (held by the player)

| ID | Asset | Size | Tris | Route | Notes |
|---|---|---|---|---|---|
| T1 | Drip torch | 0.9 m | ≤200 | PROC | Grip at the origin; the flame tip glows in code |
| T2 | Mida knife | 0.5 m | ≤150 | PROC | |
| T3 | Rake / hoe | 1.4 m | ≤200 | PROC | |
| T4 | Backpack sprayer tank (15 L) | 0.35×0.46×0.2 m | ≤300 | IMG→3D | Worn on the back |
| T5 | Sprayer wand + hose | 0.8 m | ≤150 | PROC | |

## 6. Visual effects (2D sprites, PNG with alpha)

| ID | Asset | Format | Route | Used for |
|---|---|---|---|---|
| X1 | Flame flipbook | 4×4 sheet, 512 px | IMG2D or Blender | Flame particles (currently a soft dot) |
| X2 | Smoke puffs (4 variants) | 256 px each | IMG2D | Smoke plumes and the inversion ground smoke |
| X3 | Ember / spark | 64 px | IMG2D | Bamboo explosions, jumping embers |
| X4 | Steam burst | 4×4 sheet | IMG2D | Bamboo culm explosions |
| X5 | Water spray mist | 256 px | IMG2D | Sprayer (no visual yet) |
| X6 | Ash flakes | 64 px | IMG2D | Drifting ash after burns |

## 7. UI and 2D art

| ID | Asset | Format | Route | Used for |
|---|---|---|---|---|
| U1 | Tool icons: torch, knife, sprayer | 128 px | IMG2D | HUD tool slot |
| U2 | HUD icons: clock, wind arrow, hotspot, rice, scrutiny eye, breath, water drop | 64 px | IMG2D | Top and bottom bars |
| U3 | Crew portraits (3), from the existing chibi art | 256 px | Crop / IMG2D | Crew status line, Ta-poh's wind warning |
| U4 | Hearth background painting (night hut, fire, radio) | 1920×1080 | IMG2D | Village Hearth screen |
| U5 | Hearth panel art: radio, granary, workbench, mutual aid | 512 px | IMG2D | Hearth panels |
| U6 | Title screen + logo (เงาเมฆา / Satellite Shadow) | 1920×1080 | IMG2D | No title screen yet |
| U7 | Font with Thai + emoji coverage (e.g. Noto Sans Thai / Sarabun, OFL) | .ttf | Download | Some emoji (🤝) currently don't render |

## 8. Audio (everything is synthesized today; real audio is an upgrade)

| ID | Asset | Route | Notes |
|---|---|---|---|
| A1 | Ta-poh wind warning, 2–3 Thai / S'gaw Karen lines | AUDIO (OmniVoice) | Save as `assets/audio/tapoh_wind_warning.wav`; the game picks it up automatically |
| A2 | Crew barks: whistle reply, coughing, "embers!" | AUDIO (OmniVoice) | |
| A3 | Ranger radio chatter (Thai) | AUDIO (TTS + radio filter) | Hearth forestry channel |
| A4 | Bamboo culm PANG, fire crackle loop, water hiss | AUDIO (record / CC0) | |
| A5 | Drone rotor loop, siren loop, thunder | AUDIO (CC0) | |
| A6 | Forest ambience: cicadas, birds, wind in bamboo | AUDIO (CC0) | Missing entirely today |
| A7 | Music: Tena harp + mouth organ, 3 intensity layers, 16 s loops | AUDIO (ACE-Step or commissioned) | Must loop seamlessly; layers fade in toward 20:00 |

## Priority (biggest visual gain first)

1. **C1–C4** characters (fix colours and orientation, then rig) · **E2** bamboo · **E3** brush · **E1** pine · **X1/X2** flame and smoke
2. **S1/S2** hut and barrels · **V1** drone · **E4/E5** stumps · **T1–T5** tools · **U1–U3** icons and portraits
3. **E6–E9** set dressing · **U4–U7** Hearth and title art · **A1–A7** audio · **S3–S5, V3** extras
