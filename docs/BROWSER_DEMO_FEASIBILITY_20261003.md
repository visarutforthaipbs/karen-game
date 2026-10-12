# Under Two Skies browser demo feasibility

Prepared 3 October 2026, Asia/Bangkok. Intended reader: the game owner and the people implementing the browser demo. This assessment supports a marketing channel where visitors play a representative sample, then choose to download the desktop game. The owner requires **phone and desktop play at launch**. Companion specification: [Browser demo PRD](BROWSER_DEMO_PRD.md).

**Recommendation:** fund a bounded technical and touch-control prototype using the existing Godot game. A browser export already builds and reaches the hillside on the local Mac. Public launch remains conditional on a much smaller asset pack, usable touch controls, and complete runs on actual Android phones and iPhones. If the 3D route fails those tests after the bounded prototype, choose a 2D adaptation for both phone and desktop rather than maintaining two different marketing games.

## 1 Evidence and confidence

The assessment used the current working tree, which contains existing uncommitted work. Game code, project settings and website code in the source repositories were not changed. Export changes were applied to an isolated temporary copy. The copied preset used Compatibility rendering, no threads, and the existing desktop preset's resource exclusions. This was an export probe, not an implemented demo.

| Question | Evidence gathered | Conclusion |
| --- | --- | --- |
| Can the project produce a browser package? | Installed Godot `4.7.2.stable.official.ed1daf0bf` and matching web templates; isolated release export exited 0 | Yes, demonstrated locally |
| Does anything render in a browser? | Codex in-app browser on the local Mac showed the title, opening introduction, village screen and hillside HUD at 14:00 | Initial browser rendering and scene transitions demonstrated |
| Are the exports free of obvious startup failures? | Export and 120-frame headless smoke exited 0; no error/warning entries observed in those logs or the browser console check | Limited startup check passed; not proof of full gameplay stability |
| Is the existing package suitable for marketing? | Raw export 285.80 MiB; offline gzip of the three principal files totals 241.67 MiB | No; significant content and asset reduction required |
| Does it work on phones? | No actual phone run performed; current controls require keyboard/mouse or gamepad | Unverified; required prototype gate |
| Will this increase downloads? | No browser funnel or comparable measured conversion baseline exists | Commercial hypothesis requiring an experiment |

Evidence receipts: [baseline package measurements](browser-demo/evidence/baseline.json), [source audit and hashes](browser-demo/evidence/audit.json), [export log](browser-demo/evidence/export.log), [headless smoke log](browser-demo/evidence/headless-smoke.log). The baseline includes all resources allowed by the copied exclusions, including resources the final demo will not need. These are measurements of that baseline, not a minimum achievable size. Offline gzip sizes are calculations, not observed production transfer sizes.

## 2 The product and marketing case

The browser experience should answer two questions through play: “Do I enjoy making these decisions?” and “Do I want to lead this crew through the larger campaign?” A satisfying afternoon is the advertisement. An installation requirement before that first experience puts the highest-friction step before the visitor knows whether they care.

Proposed journey: gameplay clip, article, community post or website → browser landing page → short explanation → one afternoon → honest result → desktop download or phone-to-desktop handoff. This is an additional entry point; existing download links remain available for people already convinced. A Steam wishlist destination can be added when its actual public URL is verified. The available source currently points to a free desktop beta, so the initial call to action must describe that beta accurately rather than imply a paid finished release.

Phone visitors cannot install the current desktop product on their phones. They need an explicit “Continue on computer” path using copy/share, not a misleading mobile Download button. A copied link is evidence of intent, not evidence of an installation. This distinction is central to judging the marketing channel.

## 3 Technical route comparison

The effort ranges below are planning judgments for one experienced developer with existing assets and access to test devices. They include implementation and ordinary QA, not a promised completion date. Device access, art reduction and touch playtesting may change them.

| Route | Benefits | Main costs and risks | Planning range after prototype decision |
| --- | --- | --- | --- |
| Optimized Godot 3D export | Reuses fire, crew, tools, camera, localization and current visual identity; closest sample of desktop play | Engine download overhead, texture and rig memory, browser renderer differences, touch work | About 10–18 developer-days for a shippable candidate |
| Godot 2D adaptation | Keeps Godot workflow and can extract simulation logic; baked isometric art reduces 3D draw work | New presentation, movement/targeting and asset baking; engine download remains | About 15–25 developer-days |
| TypeScript 2D adaptation | Greater control over first-load size and DOM-based web UI; can avoid a full Godot engine payload | Reimplements fire, crew and timing; two gameplay implementations can drift; substantial fidelity testing | About 20–35 developer-days |
| Cloud-stream the desktop game | Preserves native presentation | Per-session compute and streaming infrastructure, latency and touch still need work | Reject for the initial marketing channel; no cost/performance case established |

**Selected planning route:** optimized Godot 3D, conditional on the prototype gate. It is the cheapest route to representative play because the working game exists. Phone support means it cannot be selected solely because it runs on a developer Mac. No second implementation is authorized or justified by this assessment until the gate provides evidence that one is needed.

## 4 Renderer and presentation adaptations

Godot's browser export uses WebAssembly and WebGL 2 with Compatibility rendering; Forward+ is unavailable. Single-threaded export avoids the cross-origin isolation setup required by threaded export. Those documented capabilities support the chosen starting route; they do not certify this project's phones. [Godot web export](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html)

Source audit identifies specific adaptation points:

| Area | Current implementation | Proposed browser treatment |
| --- | --- | --- |
| Entry presentation | `ui/TitleScreen.gd` and `ui/TitleLogo.gd` create live 3D views; title creates a Decal | Use the approved static wordmark and a lightweight scene preview; omit the live 3D title construction |
| Lighting and mood | `scenes/Main.tscn`, `scripts/SkyCycle.gd` use glow and fog | Tune daylight, sunset and thermal visibility for Compatibility; inspect all phases rather than copy desktop values blindly |
| Scenery | `Landscape.gd` uses distant geometry, mist and some GPU particles | Start from existing low-detail setting; remove distant decoration before reducing playable-field readability |
| Fire | `FireGrid.gd` uses CPU particles and many vegetation instances | Bound visible particle counts, texture sizes and instance counts; retain distinguishable flames, smoldering cells and ash |
| HUD | `ui/HUD.gd` includes a screen-texture shader and dense desktop information | Test shader cost; replace decorative blur if necessary; build a phone HUD around goals and tools |
| Satellite | Thermal result is central to the game | Retain the scan and its consequences; avoid depending on the title's Decal for the experience |

Compatibility does not support Decals, and Godot warns that switching renderer may require scene and lighting adjustments. Therefore the title's satellite shadow needs replacement or omission. [Godot renderer comparison](https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html)

## 5 Download size and resource dependencies

| Item | Measured size | Interpretation |
| --- | --- | --- |
| All source assets | 376.30 MiB | Includes references, concepts, duplicate/static and rigged models; not shipped transfer size |
| Source character/model directory | 166.45 MiB | Main reduction opportunity; demo needs only the playable crew and necessary equipment |
| Source props | 103.53 MiB | Use only the hillside, hut, water and vegetation needed for the sample |
| Source audio | 57.79 MiB | Select a small sound set and short recorded lines |
| Baseline `index.pck` | 247.35 MiB raw / 232.01 MiB gzip | Whole-resource packaging is unsuitable; compression alone barely helps this pack |
| Baseline `index.wasm` | 37.68 MiB raw / 9.59 MiB gzip | Fixed startup cost before demo assets; custom engine trimming is a possible later optimization |

Proposed targets are ≤12 MiB compressed to first playable as an aspiration, and **≤20 MiB as the launch ceiling**. Count HTML, scripts, engine, pack, fonts and required audio, not only the game pack. These targets are product choices for the marketing experience, not evidence that the existing art can meet them. A 20 MiB payload needs approximately 16.8 seconds to transfer at 10 Mbps before latency, compilation and scene initialization. At 5 Mbps it needs approximately 33.6 seconds. Both calculations assume ideal continuous throughput and explain why real network tests matter.

Build a demo resource manifest and inspect exported contents. Existing `all_resources` presets must be replaced for the demo. Scene dependency export alone is insufficient: `AudioManager`, `AssetLibrary`, UI and localization use runtime string-based resource lookup. Conversely, shared autoloads and dynamically loaded menus can pull unwanted resources into a package or demand excluded assets at runtime. Create an explicit mapping of retained runtime lookups, their permitted fallbacks and their files before exclusion. Do not ship high-resolution production rigs and textures by default. Make reviewed web derivatives in a separate directory; preserve the desktop originals.

Default single-threaded web sample playback has audio-effect and procedural-audio limitations. This project loads recordings and generates fallback WAV streams; verify those actual paths. Proposed demo audio uses pre-baked sounds, restrained simultaneous voices and subtitles, with a Start interaction enabling playback. Stream playback is a fallback only if measured latency is acceptable. [Godot audio playback notes](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html#audio-playback)

## 6 Touch and timing feasibility

The current player controller already separates movement, aim, tools and crew signals, which is a useful input boundary. It has no audited phone control layer. Implement touch as actions consumed by the same tool and movement rules, with separate finger ownership for moving and targeting. Mouse emulation alone cannot establish simultaneous two-thumb play. [Godot touch events](https://docs.godotengine.org/en/stable/classes/class_inputeventscreentouch.html)

The clock currently runs at 90 real seconds per in-game hour: 14:00–20:00 takes 540 seconds, or nine minutes. Fire smoldering lasts 480 half-second ticks, or four real minutes, and contributes to the displayed self-cooling deadline. The prototype should first retain those timings to establish fidelity. The proposed marketing version is a five-to-six-minute afternoon, with onboarding and result bringing a first session to roughly six-to-eight minutes. That shorter version requires a separately reviewed timing profile, adjusted fire lifecycle and validation of achievable ash, cooling, crew work, water refill and escape response. Changing only `real_seconds_per_hour` is not an acceptable shortcut.

Reducing scenery and skipping campaign menus does not require changing the simulation. Reducing the grid, changing crew efficiency or accelerating time does. Keep these categories separate in performance work so that a faster browser build does not silently become a different strategy game.

## 7 Hosting and operating cost

The existing promotion site is Astro and the download site is a Cloudflare Worker with R2-backed installer delivery. Reuse the approved identity and language routes. Proposed browser routes are `/play/` and `/th/play/` on the promotion site. These routes are not created by this plan.

Cloudflare Workers Static Assets has a 25 MiB individual-file limit. The measured raw engine already exceeds it. Small shell assets can use Static Assets, but larger engine/pack objects need R2-backed delivery or a demonstrably smaller build. Serving an installer endpoint unchanged is unsafe as an implementation choice: the current download Worker deliberately sets `Content-Disposition: attachment` for archives. Browser assets need explicit inline delivery, correct MIME types, and separate routes. [Workers limits](https://developers.cloudflare.com/workers/platform/limits/)

Prefer versioned same-origin browser asset routes served from R2 through a Worker with explicit cache handling. This works with the existing infrastructure without assuming a custom domain has been bought. If a domain is available, R2 with a custom domain and suitable cache rules is another option. R2's `r2.dev` URL is a rate-limited development facility, not the proposed production origin. [R2 public buckets](https://developers.cloudflare.com/r2/buckets/public-buckets/)

R2 Standard currently includes 10 GB-month storage, one million Class A operations and ten million Class B operations monthly; internet egress is free. Worker request charges/limits and analytics are separate, and existing account usage consumes the same allowances. This supports inexpensive delivery, not an unconditional zero-cost promise. [R2 pricing](https://developers.cloudflare.com/r2/pricing/)

Illustrative delivery model, not a traffic forecast: 10,000 cold starts × 20 MiB ≈195.3 GiB transferred. If each start needs eight R2 object reads, that is 80,000 reads before caching/retries. Track actual cache misses, Worker requests, analytics writes and total account usage. Browser gameplay runs on the visitor's device; no simulation server is needed. Do not add new paid services before measured needs justify them.

## 8 Prototype decision gate

Time-box the next implementation phase to **three to five developer-days**, plus any wait for test-device access. This assessment has completed export/startup evidence; the remaining prototype must exercise an actual afternoon and touch interaction. Do not treat responsive desktop emulation as a phone test.

| Experiment | Required evidence | Decision it supports |
| --- | --- | --- |
| Demo asset pack | Manifest, raw and compressed file inventory, runtime missing-resource check | Can 3D meet the ≤20 MiB startup ceiling? |
| Actual phones | At least an ordinary Android phone and an iPhone, with exact device/browser recorded | Is both-platform launch credible? |
| Touch sample | At least six fresh phone players perform movement, firebreak, ignition, spraying, refill and pause without coaching | Is the input scheme usable enough to polish? |
| Full afternoon | Preparation, peak fire, smoke, scan and result on every baseline device; repeated runs | Are rendering, balance and stability retained? |
| Measured delivery | Cold loads at controlled 10 Mbps/100 ms RTT; warm loads; real mobile connection | Do first-play timings meet the PRD? |
| Short timing profile | Fixed-scenario outcomes and human completion compared with nine-minute reference | Does the marketing duration preserve meaningful decisions? |

Proceed with Godot 3D only when there is a credible pack within budget, no crash during complete phone runs, usable touch, and sustained frame pacing meeting the PRD. If failure is concentrated in assets or decoration, fix those within the time box. If it requires a broad renderer/animation rewrite or still misses phone budgets, make an explicit 2D architecture decision. Use the same demo on both device classes to keep acquisition and maintenance understandable.

## 9 Remaining uncertainty and decision

Technical confidence is high for exporting and reaching the first scene, medium for a small desktop demo, and presently unproven for phone launch. Marketing confidence is a testable hypothesis. No FPS, memory, actual mobile completion, production download speed, conversion lift or public browser availability is claimed.

The decision supported now is to implement the bounded prototype with phone and desktop as equal launch requirements. The decision to publish comes after device, load, gameplay and funnel checks. This browser specification supersedes earlier planning statements that web/mobile were outside the distribution scope; it does not change the desktop SKU, price, Steam schedule or existing public-beta terms.
