# PRODUCT REQUIREMENTS DOCUMENT (PRD)

# Project: Satellite Shadow (เงาเมฆา / ไร่หมุนเวียน)
**Document Version:** 1.0.0  
**Update:** v1.1 completion & test-readiness requirements are in [`PRD_UPDATE_v1.1.md`](PRD_UPDATE_v1.1.md) (title/pause/save/settings, endings, the Ranger, builds, Steam Deck, telemetry).  
**Status:** Approved & Ready for Implementation  
**Target Engine:** Godot 4.3+ (Forward+ 3D, GDScript)  
**Primary Platform:** PC (Steam / itch.io) with full Steam Deck / Gamepad support  
**Visual Style:** Stylized Low-Poly 3D (Flat-shaded, high-contrast silhouettes, dynamic atmospheric haze)  
**Genre:** Isometric Tactical Survival & Environmental Stealth Simulation (Endless Seasonal Roguelite)

---

## 1. Executive Vision & Cultural Premise

### 1.1 Premise
In the mist-shrouded highlands of Northern Thailand (Chiang Mai / Mae Hong Son), an upland Karen farming community practices *Rai Mun Wian* (ไร่หมุนเวียน — rotational fallow agriculture). To regenerate the soil and plant upland rice before the monsoons arrive, fallow brush must be burned down to fertile, mineral-rich ash.

However, the Royal Thai Government enforces draconian **Zero-Burn Decrees** backed by modern orbital surveillance: polar-orbiting NASA/NOAA satellites (VIIRS / MODIS) scanning for thermal anomalies, and low-altitude forestry quadcopters patrolling the valleys.

### 1.2 The "Satellite Shadow" Mechanic
Because sun-synchronous satellites follow deterministic orbital tracks, there exists a consistent daily operational blind spot over Northern Thailand roughly between **14:00 (2:00 PM)** and **20:00 (8:00 PM)**. 
* Igniting before 14:00 is detected by the morning Aqua/Terra passes.
* Smoldering hotspots lingering past 20:00 are caught by the nocturnal Suomi-NPP/NOAA-20 VIIRS overpass.
* The player must orchestrate a high-stakes, communal controlled burn within this 6-hour window, cool every glowing root collar before 20:00, and ensure enough ash is created to feed the village for another year.

### 1.3 Core Pillars
1. **Mechanical Dilemma, Not Preachy Exposition:** The indigenous struggle is felt through the brutal trade-off between famine (under-burning) and state violence (over-burning).
2. **Systemic Physics & Environmental Panic:** Fire reacts to realistic environmental vectors: slope steepness, valley wind shifts, bamboo culm steam explosions, and dusk temperature inversions.
3. **Mutual Aid (*เอาแรง*):** Farming is never solo. Directing and protecting your companions (Elder and Youth) is essential to survival.
4. **Endless Escalation:** Year after year, the climate grows drier, and state surveillance advances from crude satellite alerts to AI-guided thermal drones and border checkpoints.

---

## 2. Gameplay Architecture & The Core Loop

### 2.1 The Seasonal Roguelite Flow

```
                      ┌──────────────────────────────────────────────┐
                      │             YEAR START (February)            │
                      │  Inspect Rice Barn, Radio Intel & Fallows    │
                      └──────────────────────┬───────────────────────┘
                                             │
               ┌─────────────────────────────┴─────────────────────────────┐
               ▼                                                           ▼
     [ Plot 1: Lowland Fallow ]                                  [ Plot 2: Bamboo Grove ]
     (Mild slope, light fuel)                                    (Explosive steam culms)
               │                                                           │
               └─────────────────────────────┬─────────────────────────────┘
                                             ▼
                                  [ THE NIGHT HEARTH ]
                      (Rations, Tool Repairs, Radio Eavesdropping)
                                             │
               ┌─────────────────────────────┴─────────────────────────────┐
               ▼                                                           ▼
     [ Plot 3: Ridge Crest ]                                     [ Plot 4: Park Boundary ]
     (Erratic wind, drone sweep)                                 (Extreme state scrutiny)
                                             │
                                             ▼
                                [ Plot 5: Pre-Monsoon Rush ]
                                (Steep terrace, storm deadline)
                                             │
                                             ▼
                      ┌──────────────────────────────────────────────┐
                      │           ANNUAL MONSOON HARVEST             │
                      │  Rice Yield Evaluated vs. State Scrutiny     │
                      │  SURVIVED? -> Advance to Year +1 (New Tech)  │
                      └──────────────────────────────────────────────┘
```

---

## 3. Burn Day Mechanics (14:00 – 20:00)

### 3.1 Pacing & Time Compression
* **Match Duration:** 9 real-world minutes per hillside plot.
* **Time Scale:** $1\text{ real second} = 40\text{ in-game seconds}$ ($90\text{ real seconds} = 1\text{ in-game hour}$).

| In-Game Time | Real-Time | Phase Name | Environmental State | Player Objective |
| :--- | :--- | :--- | :--- | :--- |
| **14:00 – 15:30** | 0:00 – 2:15 | **Phase 1: Perimeter Raking** | Clear afternoon sun, strong valley drafts | Cut firebreaks (*แนวกันไฟ*), check wind direction, light initial backburn buffer |
| **15:30 – 18:00** | 2:15 – 6:00 | **Phase 2: The Main Conflagration** | Peak heat, rising smoke plume, drone sweeps | Ignite headfire, control slope spread, stamp flying embers, hide from drones |
| **18:00 – 19:45** | 6:00 – 8:30 | **Phase 3: Inversion & Smolder Rush** | Sunset ochre haze, trapped ground smoke, limited visibility | Douse glowing bamboo stumps and root collars with backpack sprayer |
| **19:45 – 20:00** | 8:30 – 9:00 | **Phase 4: The Satellite Countdown** | Blue hour twilight, high tension, sirens/countdown | Hunt down any remaining thermal hotspots exceeding $35\text{ MW}$ threshold |
| **20:00** | 9:00 | **Phase 5: Orbital Overpass** | Screen switches to Thermal False-Color Satellite Pass | Instant scan for thermal anomalies; fines/scrutiny calculated |

---

## 4. Physics & Simulation Systems

### 4.1 Cellular Automata Fire Grid
* **Grid Resolution:** $40 \times 40$ cells ($1.5\text{m} \times 1.5\text{m}$ per cell $\rightarrow 60\text{m} \times 60\text{m}$ hillside).
* **Cell States:**
  1. `Vegetation` (Fuel: 100, Heat: 0) — Flammable dry brush.
  2. `Firebreak` (Fuel: 0, Heat: 0) — Mineral soil scraped bare; halts ground spread.
  3. `Burning` (Fuel: Decaying, Heat: 100) — Active open flame; lethal; produces smoke particles.
  4. `Smoldering` (Fuel: 0, Heat: 45) — Red glowing root collar; **detectable by satellite**; requires dousing.
  5. `Cooled Ash` (Fuel: 0, Heat: 10) — Mineral ash bed; safe from satellite; provides rice yield.
  6. `Forest Border` (Fuel: $\infty$, Heat: 0 $\rightarrow$ 100) — National park border; burning here causes severe penalties.

### 4.2 The Fire Spread Formula
Every simulation tick ($0.5\text{s}$), each burning cell attempts to ignite its 8 neighboring cells based on probability $P$:
$$P = P_{\text{base}} \times S_{\text{slope}} \times W_{\text{wind}} \times D_{\text{fuel}}$$

* **$P_{\text{base}}$:** Base ignition coefficient ($0.28$).
* **Slope Factor ($S_{\text{slope}}$):**
  $$S_{\text{slope}} = 1.0 + (\Delta \text{Elevation} \times 1.5)$$
  * Fire pre-heats fuel uphill, spreading up to **$2.5\times$ faster** upwards.
  * Downhill spread is naturally suppressed ($0.4\times$).
* **Wind Alignment ($W_{\text{wind}}$):**
  $$W_{\text{wind}} = \max(0.2, 1.0 + (\vec{D}_{\text{spread}} \cdot \vec{V}_{\text{wind}} \times 1.3))$$
  * Strong gusts double the spread rate in the downwind vector.
  * High wind ($>1.5\text{ m/s}$) enables **Ember Jumping** across a 1-cell firebreak.
* **Bamboo Steam Explosions:**
  * When bamboo cells burn, internal trapped moisture expands, randomly launching burning sparks $2 - 4$ cells away.

### 4.3 Atmospheric Inversion & Smoke Asphyxiation
* At **18:00 (Sunset)**, the simulation spawns an atmospheric inversion layer.
* Warm air aloft traps smoke at ground level ($Z \le 2\text{m}$).
* **Camera / Visuals:** Draw distance shrinks; an oppressive sepia fog envelopes the screen.
* **Player / Companion Hazard:** Standing in dense smoke for $>4\text{ seconds}$ triggers coughing, reduces movement speed by $40\%$, and drains stamina rapidly.

---

## 5. Player, Companions & Mutual Aid (*เอาแรง*)

### 5.1 Protagonist (Kha-nae)
* **Controls:** Direct WASD / Left Stick movement with mouse aim / right stick.
* **Equipped Tools (Hotkeys `1`, `2`, `3`):**
  1. `Drip Torch` — Lights continuous ignition lines.
  2. `Mida Knife & Rake` — Scrapes brush down to bare dirt to build firebreaks.
  3. `Backpack Water Sprayer (15L)` — Douses active flames and cools smoldering embers to ash.
* **Rally Whistle (`Space` / `Bumper`):** Calls all companions to regroup at the player's position if smoke or fire closes in.

### 5.2 Companion AI Architecture

#### Companion A: Ta-poh (Elder)
* **Role:** Firebreak Master & Weather Oracle.
* **Stats:** Move speed $3.6\text{ m/s}$ (slow), Firebreak clearing speed $150\%$ (fast).
* **Autonomous Behavior:** Automatically seeks the unburned plot perimeter downwind and cuts clean firebreaks.
* **Passive Trait (Wind Intuition):** Shouts a warning **$10\text{ seconds}$ before a valley wind shift**, giving the player time to react.

#### Companion B: Mu-naw (Youth)
* **Role:** Sprayer Scout & Hotspot Hunter.
* **Stats:** Move speed $5.2\text{ m/s}$ (fast), Extinguishing efficiency $140\%$.
* **Autonomous Behavior:** Patrols burned areas to find and extinguish smoldering stumps.
* **Passive Trait (Thermal Eye):** Emits a faint pulse highlighting smoldering roots hidden under smoke within a $12\text{m}$ radius.

#### Contextual Ping System
* **Right-Click on Brush:** Commands Ta-poh to prioritize clearing that firebreak line.
* **Right-Click on Fire / Embers:** Commands Mu-naw to sprint and douse the target tile.

---

## 6. Surveillance & Detection Systems

### 6.1 Polar-Orbiting Thermal Satellites (VIIRS / MODIS)
* Satellite sweep triggers at precisely **20:00**.
* **Detection Criteria:**
  $$\text{Hotspot Detected if } T_{\text{cell}} \ge 35.0\text{ Thermal Units}$$
* Each detected hotspot adds **$+15\text{ State Scrutiny}$**.

### 6.2 Low-Altitude Forestry Drones (Daylight)
* Active between **15:00 and 18:00**.
* Patrols diagonally across the map with a cone of vision and thermal camera.
* If a drone spots an active flame or uncamouflaged crew in an open area:
  * Drone hovers and photographs coordinates.
  * Adds **$+20\text{ Scrutiny}$**.
  * **Counterplay:** Hide under dense bamboo canopy or extinguish visible tall flames when the drone engine hum grows loud.

---

## 7. The Night Village Hearth (Meta-Progression & Intermission)

Between burning days, the game transitions to the **Village Hearth screen**:

1. **The Transistor Radio:**
   * Tune frequency to listen to Royal Forestry Department ranger chatter, regional wind forecasts, and satellite drift updates.
2. **Granary & Rations:**
   * Allocate harvested rice to sustain village health and companion stamina.
3. **Mutual Aid (*เอาแรง*) Exchange:**
   * Lend labor to neighboring hamlets to secure borrowed backpack sprayers, extra water containers, or high-yield indigenous seeds.
4. **Workshop:**
   * Replace worn rubber seals on sprayers (increases water pressure).
   * Sharpen knives (speeds up firebreak clearing).

---

## 8. Win, Loss & Escalation Logic

### 8.1 Dual Failure Conditions
* **Village Famine:** Rice Barn Reserve drops below **$20\%$**. The community starves and is forced to abandon the mountain for lowland bonded wage labor.
* **State Crackdown:** State Scrutiny reaches **$100$**. Armed forestry rangers raid the village, confiscate tools, and arrest the village elders.

### 8.2 Endless Escalation (Year-over-Year Progression)
* **Year 1:** Baseline VIIRS satellite overpass at 20:00; lenient rangers; standard rainfall.
* **Year 2:** Single daytime forestry drone deployed; regional drought increases fire spread speed by $25\%$.
* **Year 3:** Dual drone patrols; ground thermal cameras placed along the National Park boundary.
* **Year 4+:** Military checkpoint roadblocks; high-speed quadcopters; zero-tolerance nighttime curfew.

---

## 9. Audio & Visual Specifications

### 9.1 Visual Direction
* **Style:** Faceted Low-Poly 3D with un-smoothed normals, stylized gradient textures, and bold silhouettes.
* **Asset acceptance rule (all pipelines):** Characters, props and environments must read as one stylized low-poly game at gameplay distance. Use simple angular forms, visible facets, broad colour areas and restrained painted details. Preserve culturally meaningful clothing patterns and construction details in simplified form. Reject photorealistic surfaces, dense microtexture, noisy normal maps and glossy realism.
* **Quality upgrades:** Improve silhouette, proportions, structure and reference fidelity within this art direction. Higher generation resolution, texture resolution or triangle ceilings do not relax the low-poly requirement. Review every candidate beside the existing scene before installation; a technical validation pass alone cannot approve its style.
* **Palette:**
  * Daytime: Lush mountain emerald green, bamboo straw yellow, terracotta clay soil.
  * Evening: Heavy ochre/sepia inversion haze, charcoal ash black, glowing ruby/amber embers.
  * The State: Harsh cold-white drone searchlights, infrared false-color thermal overlays.

### 9.2 Diegetic Soundscapes
* **Sound Effects:**
  * Crackling dry brush.
  * Sharp, firecracker-like *PANG* of exploding green bamboo culms.
  * Heavy hiss of pressurized water hitting hot charcoal.
  * Distant rhythmic thumping of forestry quadcopter propellers.
* **Music:** Minimalist, atmospheric Northern Thai and Karen instruments (Tena harp, bamboo mouth organ) that intensify dynamically as the 20:00 satellite deadline approaches.

---

## 10. Technical Roadmap & Milestone Deliverables

### Milestone 1: The Core Physical Simulation (Done)
- [x] Godot 4 project initialization.
- [x] 40x40 Cellular Automata fire spread script with slope and wind bias.
- [x] MultiMesh GPU instancing for 1,600 cells in 1 draw call.
- [x] Time compression clock (14:00 – 20:00).
- [x] WASD player movement with tool switching.
- [x] Basic companion state machine and ping dispatch.

### Milestone 2: Environmental Hazards & Atmospheric Inversion (Done)
- [x] Implement dynamic wind vector shifting with audio cue (Ta-poh voice warning). *Synthesized call; drop a recorded `assets/audio/tapoh_wind_warning.wav` in to replace it.*
- [x] Implement bamboo steam-explosion spark hopping (plus high-wind ember jumping across 1-cell firebreaks).
- [x] Add post-processing atmospheric inversion fog shader that activates at 18:00 (screen-space sepia/haze shader + ground-hugging height fog).
- [x] Implement smoke asphyxiation stamina drain on player and companions (companions cough, slow down and flee thick smoke).

### Milestone 3: Surveillance & Drones (Done)
- [x] Implement Forestry Drone waypoint patrol with vision cone (multiple drones, mirrored routes, rotor hum by proximity).
- [x] Implement False-Color Infrared Satellite Pass screen at 20:00 (heat-mapped hillside, scan line, anomaly markers, legend).
- [x] Hotspot anomaly logging and State Scrutiny calculation (GISTDA-style lat/lon log in the report and campaign state).

### Milestone 4: The Village Hearth & Endless Meta-Loop (Done)
- [x] Build the Night Hearth UI (Transistor radio with live forecasts, granary rations, workshop upgrades, mutual-aid exchange, annual monsoon harvest).
- [x] Procedural hill generator for subsequent plots (varying slopes, fuel densities, and park borders).
- [x] Year-over-year surveillance escalation manager (`scripts/Escalation.gd`).

### Milestone 5: Audio, Visual Polish & Steam Deck Verification (Mostly done)
- [x] Low-poly 3D models for bamboo groves, upland huts, and tools (procedural, `scripts/LowPoly.gd`). *Characters are built separately via the SOP.md pipeline.*
- [x] Full diegetic audio integration (radio chatter, bamboo explosions, Karen harp). *All procedural (`scripts/AudioManager.gd`); no audio files.*
- [x] Gamepad / Steam Deck controller binding (`scripts/InputBindings.gd`). *Not yet verified on physical Steam Deck hardware.*

### Character production and skeletal animation

The production sequence is defined in [SOP.md](SOP.md): refined textured mesh →
visual acceptance → calibrated rig/skin → animation and deformation review →
Godot integration. Technical mesh validity alone is not visual acceptance.

- [x] Kha-nae refined textured candidate: 39,799 triangles, 2K textures.
- [x] Kha-nae initial 19-bone skeleton and weighted skin; rigid head/hat.
- [x] Idle, in-place Walk/Run and legacy ToolUse clips; runtime transitions and hand tool attachment.
- [x] Semantic work state, aim-facing while moving, smoke reaction, interruption handling and successful-action feedback.
- [x] Separate rake, ignition and spraying runtime poses, including two-hand rake targets.
- [ ] Final hand/tool contact polish (finger closure remains optional for close-ups).
- [x] Bounded terrain foot correction and directional step targets.
- [ ] Final terrace-edge contact and high-speed stride polish.
- [x] Calibrated rigs and animation review for Ta-poh and Mu-naw.
- [ ] Facial/finger animation if required by future close-up scenes.

The first gameplay rig is not a claim of finished animation quality or automatic
rigging for arbitrary generated characters. Evidence and known limits are kept
under `artifacts/khanae_rigging/` and `artifacts/character_motion_20261002/`.
Distinct runtime tool poses and bounded foot correction are implemented; the
remaining contact/stride items are visual polish, not missing companion skeletons.
