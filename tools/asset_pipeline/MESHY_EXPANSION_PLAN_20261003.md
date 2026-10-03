# Remaining-credit asset and motion plan — 2026-10-03

Status: executed after the user approved the **250-credit cap** ("yes do it").
Spent **213 credits**; verified remaining balance **1,113**. Four current props
installed; four future props staged separately. The first animation pilot was
rejected, so the other five were not submitted. See
[MESHY_EXPANSION_HANDOFF_20261003.md](MESHY_EXPANSION_HANDOFF_20261003.md) for final
counts, review evidence and remaining GAME work. The plan below is the approved
proposal; proposed costs and geometry problems describe the pre-work state.

## Evidence and scope

Read SOP, PRD §7, PRD_UPDATE_v1.1 P2-8, ASSET_REQUESTS_v1.2, the installed
Meshy cast inventory and equipment/polish handoffs. Re-ran strict quality prop
validation and rendered V1/V2/S5/V3 from four angles. Evidence:
`artifacts/asset_credit_audit_20261003/{inventory.json,current_surveillance.png,render.log}`.
All five saved Meshy rig tasks still report SUCCEEDED. Those read-only status
responses report the original 5-credit charge; this audit did not rerig them.

The approved six character GLBs already contain game-compatible rigs and clips.
Their current weights/skeleton differ from the native Meshy rig. Animation
candidates must therefore be retargeted; downloading a clip does not make it
usable in our game. Preserve Kha-nae's locked likeness, every approved costume,
the two dress controls, current work layers and equipment sockets.

## Priority and acceptance

| Priority | Item | Reason and contract | Proposed Meshy cost |
|---|---|---|---:|
| First, local | V3 satellite | Attractive current silhouette; fails 4,000-triangle limit (5,335), 2 m max-span and Y=0 grounding. Repair without regeneration, preserve two X wings, +Z flight and -Y scanner; inspect title staging afterward. Runtime bounding-box recentering remains unchanged. | 0 |
| 1 | V1 drone replacement candidate | Improve body/camera and motor readability. No generated propellers; motor centres must remain X/Z ±0.48 m and match runtime disc height. 1.2 m span, ≤3,000 tris. Compare actual rotating discs, not only isolated GLB. | 30 |
| 2 | V2 camera replacement candidate | Current housing is a simple box. Improve lens hood and weatherproof silhouette. Housing only; preserve runtime pole and separate warning lens (world/local actor point 0,2.7,0.26), +Z view, ≤1,500 tris. | 30 |
| 3 | S5 checkpoint replacement candidate | Improve roadside sign, bases and sandbags. Current static GLB includes a horizontal beam while ui/CheckpointScene.gd supplies an independent animated barrier. New static dressing must avoid duplicating/blocking that moving arm. 3 m maximum X/Z span, ≤3,000 tris, fictional/unmarked. Review the actual checkpoint before install. | 30 |
| 4 | Six motion pilots | Four crew idle candidates, Mae-Lu conversation and ranger alert/scan. Use existing native rig tasks; transfer only suitable motion onto installed game skeletons. No character regeneration or rerig charge. | 18 |
| 5, future library | Transistor radio | PRD §7 radio panel and future 3D Hearth. Unmarked receiver, broad matte shapes; blank dial, no generated writing. New static ID/budget and placement to be agreed with GAME. | 30 |
| 6, future library | Repair workbench | PRD §7 workshop: plain timber bench with simple tool/seal compartments; handheld tools remain separate. New ID/budget; no runtime placement exists yet. | 30 |
| 7, future library | Rice storage/measure basket | Granary/rations and future village dressing. Research a documented local Pgakenyaw example before designing; generic basket imagery does not establish cultural authenticity. No invented ethnic motifs. New ID/budget; unintegrated future candidate. | 30 |
| 8, future library | Empty granary variant | Famine ending calls for an empty granary; current S3 exterior is closed. Derive a structurally consistent open-door/interior version from the accepted design. ≤6,000 tris; store separately, keep existing S3 in production until an appropriate hook/placement is available. | 30 |

Seven textured Meshy-7 prop jobs at 20 mesh + 10 texture credits = **210**.
Six library animation jobs at 3 credits = **18**. Proposed total **228**,
with **22** reserved for justified remeshing/retexture/alternative clips within a
**250-credit cap**. No extra full 30-credit retry fits that reserve. Stop and
record rejected outputs rather than exceeding the cap. At full cap, at least
**1,076 credits** remain, assuming no unrelated account usage. Do not spend the
balance merely because it exists.

## Animation pilot requests

Official catalog checked: https://docs.meshy.ai/en/api/animation-library
Pricing/retarget semantics: https://docs.meshy.ai/en/api/animation

| Character | Existing native rig task | Action ID / source clip | Intended test |
|---|---|---|---|
| Kha-nae | 01a0fb85-3b15-72e8-93e9-35f28fda29f9 | 0 / Idle | Grounded idle without disturbing hat/face or tool layering |
| Ta-poh | 01a0fb45-3b59-73d8-9e92-07f32200be66 | 11 / Idle_02 | Quiet elder idle, inspect belt knife and shoulders |
| Mu-naw | 01a0fb46-7e31-7153-ad67-cea12baf73a3 | 12 / Idle_03 | Inspect closed dress and tank/hose during idle |
| Mae-Lu | 01a0fb46-9432-7267-a81b-84829cda8a95 | 0 / Idle | Keep hands inside portrait framing |
| Mae-Lu | same | 56 / Stand_and_Chat | Candidate for existing Talk; inspect closed hem and portrait |
| Ranger | 01a0fb45-51ab-7159-9ee6-bc0e931504b5 | 2 / Alert | Candidate for existing Scan; verify flashlight/socket contact |

These are candidates, not claims of better motion. Reject identity/geometry
changes, unsuitable attitude, floor sliding, incompatible loops, excessive
stretch or tool interference. Preserve existing clip names/timing where required
by controllers. Ordinary Meshy animation does not automatically create finger
closure, precise rake targets, flexible hose attachment or facial acting.
Free provider walking/running sources already exist; do not buy duplicates.
If the first pilot cannot be transferred safely, stop motion spending and document
the incompatibility rather than generating the other five blindly.

## Keep and defer

- Keep the newly accepted S2/S3/S4/S6/T4 and approved characters. S4 is delivered,
  but current 2D Hearth does not place those houses; PRD P2-8 needs GAME work.
- Keep the recent vegetation/VFX/tool polish. Grass must stay ≤40 tris and
  repeated vegetation one vertex-colour surface. Dense Meshy regeneration would
  not address these constraints. Terrace mating planes remain X=±0.75 m.
- C6 remains four static walking poses ≤3,000 tris, 1.15 m. No crowd rigging.
- Finger/face rigs, deep crouches and exact work motions need a separate contract
  and review; spending credits alone does not certify them.
- Music synchronization, Hearth layout, export size and gameplay placement are
  AUDIO/GAME tasks, not reasons to generate more Meshy models.

## Delivery rules

Generate isolated concepts matching the existing faceted, muted low-poly game.
Research uncertain cultural objects before paid submission, using the reference
brief's Pgakenyaw/locality distinctions. Preserve task parameters, IDs, raw
downloads, costs and rejections. Build/validate candidates on CPU where useful.
Review four angles, actual gameplay distance and relevant scene/equipment hook.
Install passing current-asset replacements in batches with rollback, run
tests/test_all.gd after each install, and record counts, offsets and review paths
in V12_ASSET_HANDOFF.md. Future objects stay clearly unintegrated until GAME
supplies placements/contracts. Do not edit scripts/, ui/ or tests/test_all.gd.

Cost gate comes from the installed Meshy MCP instructions, Rule 1:
"Before calling ANY tool that costs credits, present the cost and wait for user confirmation."
Prior 105-credit approvals covered their specific completed batches, not this plan.
