# AGENT INSTRUCTION & ARCHITECTURE MANUAL (AGENT.md)
## Project: Satellite Shadow (เงาเมฆา / ไร่หมุนเวียน)

This document provides explicit guidelines, environment topology, and command protocols for AI Agents operating on the Satellite Shadow codebase.

---

## 1. System Topology & Available Compute

Agents have direct access to two computational environments:

| Node Name | Environment | Connection | Hardware Specs | Primary Responsibilities |
| :--- | :--- | :--- | :--- | :--- |
| **Local Host** | macOS (Darwin x86_64/arm64) | Direct Terminal | Apple Silicon (Metal 4.0) | Godot 4.7 engine runtime, GDScript code, 2D image generation, audio synthesis, git |
| **GPU Node** | Ubuntu 26.04 LTS | `ssh gpu "<command>"` | NVIDIA RTX 3090 (24GB VRAM), 45GB RAM | High-VRAM 3D neural inference (TripoSR), heavy mesh decimation, ComfyUI |

---

## 2. Directory Structure Map

```
/Users/lighthouse-control/Desktop/hill-blackmirror/
├── PRD.md                      # Canonical Product Requirements Document
├── SOP.md                      # Standard Operating Procedure for 3D AI Pipeline
├── AGENT.md                    # Agent Operational Protocol (This document)
├── project.godot               # Godot 4 project configuration
├── assets/
│   ├── concept_art/            # 2D character model turnaround sheets
│   └── models/                 # Game-ready 3D character GLB/FBX assets
├── scenes/
│   ├── VillageHearth.tscn      # Intermission screen (Radio, Granary, Upgrades)
│   └── Main.tscn               # Core 3D burn simulation on hillside
├── scripts/
│   ├── InputBindings.gd        # [Autoload] Keyboard/mouse + gamepad / Steam Deck actions
│   ├── GameState.gd            # [Autoload] Campaign state: rice, scrutiny, rations, favours, hotspot log, harvest
│   ├── AudioManager.gd         # [Autoload] Procedural SFX, loops and Tena harp / khaen music (no audio files)
│   ├── Escalation.gd           # Year-over-year surveillance & drought rules (PRD §8.2)
│   ├── PlotGenerator.gd        # Per-plot config: terrain style, park borders, wind, drones
│   ├── FireGrid.gd             # Cellular automata fire + terrain, props, particles, thermal view
│   ├── LowPoly.gd              # Procedural flat-shaded props (pines, bamboo, brush, hut, tools)
│   ├── AssetLibrary.gd         # Loads pipeline props from assets/props (falls back to LowPoly)
│   ├── GameClock.gd            # 14:00 - 20:00 time progression & orbital pass
│   ├── SkyCycle.gd             # Afternoon -> blue hour lighting, inversion fog, storm front
│   ├── WindManager.gd          # Dynamic valley wind vector shifts
│   ├── ForestryDrone.gd        # Daylight quadcopter patrol & photo detection
│   ├── ThermalCamera.gd        # Year 3+ ground thermal cameras on the park boundary
│   ├── SatelliteOverpass.gd    # 20:00 False-color VIIRS infrared scan + hotspot markers
│   ├── PlayerController.gd     # Movement, tools, water tank, breath/coughing, whistle, gamepad aim
│   ├── CompanionController.gd  # Elder & Youth mutual aid autonomous AI (smoke, flee, Thermal Eye)
│   ├── MainController.gd       # Burn-day orchestration: phases, schedule, scrutiny, report
│   └── ChibiAnimator.gd        # Character animation (owned by the character pipeline)
├── assets/fonts/               # Kanit (village UI) + Chakra Petch (state readouts), OFL
└── ui/                         # All UI is built in code; all player-facing text is Thai
    ├── UITheme.gd              # Palette, fonts, shared Theme, label/card/icon builders
    ├── FacetCard.gd            # Triangulated low-poly panel (chamfered, accent ridge)
    ├── LowPolyIcon.gd          # Flat-shaded polygon icons (flame, drop, satellite...)
    ├── SegmentBar.gd           # Slanted segment meter with threshold markers
    ├── WindCompass.gd          # Screen-space wind arrow for the isometric camera
    ├── HearthBackdrop.gd       # Low-poly night ridges behind the Village Hearth
    └── HUD.gd                  # Burn-day HUD, banners, satellite pass, report
```

---

## 3. Remote GPU Node Execution Protocol

### 3.1 Verification & Health Check
Before running any heavy neural task on the GPU node, the agent MUST run preflight health checks:
```bash
ssh gpu "nvidia-smi --query-gpu=name,memory.total,memory.free,utilization.gpu --format=csv,noheader"
```

### 3.2 Python Environment
The GPU node contains two active virtual environments:
* **Primary AI Env:** `~/aienv/bin/python3` (Contains PyTorch 2.12 with CUDA 13.0)
* **Conda Env:** `~/miniconda3/envs/ai-dev/bin/python3`

### 3.3 File Transfer Between Local Host and GPU Node
* Push asset to GPU:
  ```bash
  scp <local_path> gpu:<remote_path>
  ```
* Pull generated 3D asset back to Local Host:
  ```bash
  scp gpu:<remote_path> <local_path>
  ```

### 3.4 3D Character Pipeline Protocol
For the current quality character route, use the candidate runner described in SOP.md:
```bash
python3 tools/character_pipeline/run_refined_character.py --image <image_path> --name <character_name> --height 1.20
```
* **Candidate Outputs:** `artifacts/character_candidates/`; visual review precedes production installation.
* **Production Assets:** `assets/models/<name>_textured.glb`; reviewed skeletal versions use `<name>_rigged.glb`.
* **Rigging:** `run_rig.py --input <reviewed.glb> --profile <calibrated-profile.json>`. Kha-nae has a calibrated profile; other meshes need landmark and weight review.
* **Legacy Prototype Route:** `generate_character.sh` retains the older TripoSR workflow.
* **Rigging Specs:** See [`tools/character_pipeline/rigging_guide.md`](tools/character_pipeline/rigging_guide.md).
* **Registry & Benchmarks:** See [`tools/character_pipeline/PIPELINE_DASHBOARD.md`](tools/character_pipeline/PIPELINE_DASHBOARD.md).

---

### 3.5 Prop Asset Pipeline Protocol (non-character assets)
Concept image (or existing mesh) -> TripoSR -> headless Blender 4.5 cleanup on the GPU node -> `assets/props/<ID>_<name>_<variant>.glb`, which the game loads automatically (`scripts/AssetLibrary.gd`, procedural fallback).
```bash
./tools/asset_pipeline/build_asset.sh <ID> --prompt              # concept-image prompt for an ASSETS.md ID
./tools/asset_pipeline/build_asset.sh <ID> --image concept.png   # build (about 40 s)
./tools/asset_pipeline/build_asset.sh <ID> --mesh model.glb      # clean up an existing model
python3 tools/asset_pipeline/validate_assets.py                  # check every prop
```
Specs live in `tools/asset_pipeline/asset_manifest.json`; details in `tools/asset_pipeline/README.md`.

## 4. Game Engine Validation Rules

Whenever GDScript or `.tscn` files are modified:
1. **Never commit without headless verification:**
   Always run:
   ```bash
   godot --headless --path /Users/lighthouse-control/Desktop/hill-blackmirror --fixed-fps 60 --quit-after 120
   ```
2. **Re-index classes if new scripts with `class_name` are added:**
   ```bash
   godot --headless --editor --quit --path /Users/lighthouse-control/Desktop/hill-blackmirror
   ```
3. **Autoload Rules:**
   Never add `class_name <Name>` to a script that is registered under `[autoload]` in `project.godot`. It causes Godot parse errors. Use `extends Node` directly.

---

## 5. Cultural & Mechanical Integrity

1. **Rai Mun Wian (ไร่หมุนเวียน):** Preserve the authentic representation of rotational upland farming—not destructive slash-and-burn, but sustainable traditional agroecology.
2. **Mutual Aid (เอาแรง):** The player should never be forced to micromanage every click. Companions must maintain helpful role autonomy (Elder raking firebreaks, Youth dousing hotspots).
3. **The Satellite Shadow:** The 14:00 to 20:00 window is non-negotiable. All mechanics revolve around cooling thermal signatures before the 20:00 VIIRS night-pass.
