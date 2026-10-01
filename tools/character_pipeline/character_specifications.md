# Character Specifications & Design System
**Project:** Satellite Shadow (เงาเมฆา / ไร่หมุนเวียน)  
**Aesthetic:** Cute Low-Poly Chibi (2.5–3 Heads Tall) with Authentic Karen Mountain Culture  
**Target Engine:** Godot 4.7+ (Forward+ Metal / Vulkan)  
**Current installed assets:** textured characters use 11,940–39,779 triangles. The 2,000–3,000-triangle / vertex-colour standards below describe the retained legacy prototypes; use the pipeline README and recorded run metrics for the textured route.  

---

## 1. Character Roster

### 1.1 Kha-nae (ขะแน) — Rotational Farmer (Protagonist)
* **Archetype:** Experienced Karen highland farmer balancing rotational fire with environmental stewardship.
* **Proportions:** 2.8 Heads tall, sturdy athletic chibi build.
* **Height Scale:** 1.20m in-engine.
* **Costume & Cultural Markers:**
  * **Headwear:** Wide conical bamboo straw hat (*ขลุบ* / Highland Ngob) casting gentle shade over eyes.
  * **Upper Body:** Deep indigo-dyed handwoven cotton tunic (*ชุดกะเหรี่ยงย้อมคราม*) with geometric scarlet/terracotta chest borders (*ลายเรขาคณิต*).
  * **Lower Body:** Durable dark indigo trekking trousers tucked into laced mountain boots.
  * **Gear:** Leather tool sling across the chest carrying fire striker and field canteen.
* **Active 3D Asset:** `assets/models/khanae_textured.glb` (39,255 tris, 2K textures, unrigged).
* **Concept Art:** `assets/concept_art/khanae_front_a_pose.jpg`.
* **Turnaround Sheet:** `assets/concept_art/khanae_turntable.png`.

---

### 1.2 Ta-poh (ตาโพ) — The Village Elder (Companion)
* **Archetype:** Highland custodian of customary rotational calendars (*ปฏิทินฤดูกาลไร่หมุนเวียน*), weather omens, and wind patterns.
* **Proportions:** 2.5 Heads tall, slightly stooped dignified posture, gentle rounded cheeks.
* **Height Scale:** 1.15m in-engine.
* **Costume & Cultural Markers:**
  * **Headwear:** Traditional scarlet-and-white coiled cotton headwrap (*ผ้าโพกศีรษะกะเหรี่ยง*).
  * **Facial Features:** Soft sage white beard tuft, warm crinkling eyes.
  * **Clothing:** Heavy scarlet and cream woven elder vest over a natural hemp undertunic.
  * **Gear:** Hardwood walking stick / ceremonial clearing blade.
* **Active 3D Asset:** `assets/models/tapoh_textured.glb` (11,940 tris, 2K textures, unrigged).
* **Concept Art:** `assets/concept_art/tapoh_front_a_pose.jpg`.
* **Turnaround Sheet:** `assets/concept_art/tapoh_turntable.png`.

---

### 1.3 Mu-naw (มูนอ) — The Agile Youth (Companion)
* **Archetype:** Energetic, swift-footed village youth responsible for perimeter watch and rapid ember suppression.
* **Proportions:** 2.6 Heads tall, lean and bouncy silhouette.
* **Height Scale:** 1.10m in-engine.
* **Costume & Cultural Markers:**
  * **Headwear:** Folded woven bamboo cap with ventilation holes.
  * **Clothing:** Earthy mountain-moss green sleeveless tunic with bright yellow geometric woven fringe.
  * **Signature Gear:** 15-liter knapsack brass water tank (*ถังพ่นน้ำดับไฟป่าสะพายหลัง*) with flexible hose and brass nozzle.
* **Active 3D Asset:** `assets/models/munaw_textured.glb` (39,779 tris, 2K textures, unrigged).
* **Concept Art:** `assets/concept_art/munaw_front_a_pose.jpg`.
* **Turnaround Sheet:** `assets/concept_art/munaw_turntable.png`.

---

## 2. Legacy Prototype Technical Standards

| Attribute | Specification | Rationale |
| :--- | :--- | :--- |
| **Polygon Budget** | 2,000 – 3,000 Tris | Faceted low-poly style matches stepped mountain terraces and ensures 60+ FPS on all devices. |
| **Coordinate System** | Y-Up, X-Right, -Z-Forward | Standard Godot 4 / OpenGL engine coordinates. |
| **Pivot & Grounding** | Origin `(0, 0, 0)` at feet sole | Prevents floating or floor clipping during slope navigation. |
| **Color Pipeline** | Vertex Colors (`COLOR` stream) | Eliminates texture filtering blur, memory overhead, and UV seams while keeping vibrant colors. |
| **Shading Mode** | Toon Diffuse + Specular with Rim Lighting | Adds playful warmth and ensures character silhouettes read instantly against lush vegetation. |
| **Export Formats** | `.glb` (Binary glTF) & `.obj` | `.glb` for direct Godot engine import; `.obj` for external DCC / auto-rigging software. |

**Validation:** `tools/character_pipeline/validate_character_assets.py` checks triangle/vertex counts, height, grounding, centering, and vertex colors against the registry above. It validates the retained legacy files, not the active textured assets. Textured geometry measurements and multi-angle renders are recorded in the run deliverables.

---

## 3. Future Character Roadmap
1. **Mae-Lu (แม่หลวง):** Village Headwoman & Granary Keeper (Village Hearth Hub).
2. **Forester Somchai (เจ้าหน้าที่วนศาสตร์):** Ground patrol ranger with binoculars and handheld VHF radio.
3. **Forest Drone (โดรนตรวจจับความร้อน):** Patrol quadcopter with searchlight gimbal and thermal sensor.
4. **Wildlife Assets:** Highland Mountain Boar, Gibbons (*ชะนี*), Crested Serpent Eagle.
