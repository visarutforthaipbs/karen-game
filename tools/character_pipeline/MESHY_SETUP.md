# Meshy character pipeline

User decision: 2026-10-02. Meshy is the generation provider for new character
assets. Updated user decision, 2026-10-03: selected prominent props may also use
Meshy generation, retaining local cleanup/validation and procedural routes for
small or heavily instanced assets. See the
[remaining-credit plan](../asset_pipeline/MESHY_EXPANSION_PLAN_20261003.md).
The complete reviewed replacement cast is installed; see
[MESHY_CAST_HANDOFF.md](MESHY_CAST_HANDOFF.md).

Meshy also provides [cloud auto-rigging](https://docs.meshy.ai/en/api/rigging)
and [animation exports](https://docs.meshy.ai/en/api/animation). Review those
outputs first and preserve compatible source skin/animations. Local rebuilding
is not a required Meshy stage. Our installed cast currently uses an adapter for
the existing named-bone game controller and custom tool layers. The Blender
adapter runs on CPU, including when hosted on the machine called `gpu`.
Any future runtime change to accept native Meshy rigs belongs to GAME; record
the required mappings rather than silently editing scripts/ or ui/.

## Installed MCP

- Official package: `@meshy-ai/meshy-mcp-server@0.5.2` (exact version).
- Installation: `/Users/lighthouse-control/.local/share/meshy-mcp/`.
- Runtime: `/opt/homebrew/bin/node`; package entry point:
  `node_modules/@meshy-ai/meshy-mcp-server/dist/index.js` under that installation.
- Codex server name: `meshy`, in `/Users/lighthouse-control/.codex/config.toml`.
- Transport: stdio. Enabled; API key stored only in the local Codex configuration
  with owner-only file access.
- Authenticated MCP initialization, discovery of all 24 tools, and the read-only
  `meshy_check_balance` tool passed on 2026-10-02. The balance at that check was
  1,034 credits; this is a snapshot, not a live balance.
- Installation itself submitted no paid generation. The later approved cast run
  generated and installed the complete cast. Its final balance check returned
  **1,619 credits**; account credits changed during the run, so balance differences
  are not a reliable cost ledger. Saved task records are authoritative.

## Authentication maintenance

The key is already configured and the server is enabled. For future key changes,
update `MESHY_API_KEY` in the `meshy` server environment in local Codex MCP settings. The equivalent local config change is to add the real key to
`[mcp_servers.meshy.env]` and set `enabled = true` in `[mcp_servers.meshy]`.
The registration also permits forwarding `MESHY_API_KEY` from the Codex process
environment. Keep the key outside this repository and out of chat/logs.
Restart the MCP connection or Codex, then check initialization and tool discovery.
The server validates the key on startup. Verify account access before submitting
the first character job; installation alone does not establish authentication.

## Character delivery procedure

1. Use the approved v3.1 character direction and isolated full-body references.
   Preserve identity, proportions and cultural details; record reference sources.
2. Generate a Meshy image-to-3D candidate (consistent multi-view references may
   use multi-image-to-3D). Save task ID, inputs, parameters and downloaded outputs
   under a fresh `artifacts/character_candidates/` directory. Record retries and
   review decisions. Do not overwrite production models directly.
3. Compare front, side, back and close-up views with the approved reference and
   the other characters. Require angular silhouettes, visible facets, broad
   colours and restrained detail. Reject poor faces/hands, bridged limbs,
   costume changes, holes or realistic/glossy styling even if mesh tests pass.
4. Prepare the reviewed game mesh: per-character triangle budget, materials,
   textures, scale, grounding and +Z front. Preserve the original Meshy download.
5. Obtain/review rig and animation candidates. Meshy supplies rigging and animation
   tools; local Blender processing remains available for retargeting or repair.
   Do not reuse old rig profiles without checking landmarks, bones and weights.
   Follow `rigging_guide.md` and `gameplay_motion.md` for required clips, work
   layers, tool grips, dress motion and equipment sockets. Rigging is not waived.
6. Review deformation and motion in Godot at actual gameplay scale. Install only
   reviewed replacements, retain rollback copies, and run `tests/test_all.gd`
   after each installation batch. Record mesh counts, animation names, offsets,
   review images and results in the character handoff. Report incompatible game
   hooks to GAME rather than silently changing game-owned code.

Meshy is a generation provider, not an automatic quality approval. The existing
SOP style and gameplay gates still determine whether a character ships.

## Reproduce the reviewed cast

The official MCP tool client is `meshy_call.py request.json result.json`. It reads
credentials from the local Codex server configuration, refuses to overwrite a
saved result, and leaves task IDs on disk. Never blindly retry generation after
a timeout: recover the existing task first. The official server may itself retry
HTTP transport failures.

Approved settings: `meshy_image_to_3d`, `ai_model=meshy-7`, standard model,
T-pose for principals, triangle topology, target 19,900, 2K albedo, PBR off,
remesh enabled, GLB output. C6 uses image references, original walking pose and
a 2,800 target. C6 is registered with route `meshy`; the prop CLI refuses local
image generation/retexturing for it and accepts reviewed static GLBs. Text-only
crowd candidates were rejected for inconsistent proportions.

Use `meshy_rig` once per accepted principal with its exact height. Preserve the
raw rig and free walk/run downloads. The delivered game rigs use Meshy's joint
landmarks with recalibrated local weights and the game's named clips; the raw
auto-skin was not suitable for the gameplay poses.

`adapt_meshy_rig.py` runs in Blender 4.5 and is deliberately restricted to the
reviewed source hashes. It preserves geometry/UVs; rebuilds the 19/21-bone game
contract; calibrates shoulder, crotch and skirt weights; removes Meshy rig-export
emission; sets matte materials; and bakes the existing clips. A new source needs
fresh calibration, not just a hash added to the allowlist. The tested run retained
the 3.5 edge-stretch gate. T-pose arm lowering legitimately needs a larger
rest-to-pose displacement allowance than the old A-pose mesh.

Run `validate_meshy_delivery.py`, real-renderer `test_v31_candidates.gd` on flat
and slope/cough, `check_ranger_rig.gd` for both ranger palettes, and four-angle
visual/tool reviews before installation. Then run the complete gameplay suite
and installed character-contract tests. Snapshot scripts, hashes, all rejected
attempts and raw downloads. See the handoff for exact accepted versions.

## Sources

- [Meshy Codex setup](https://www.meshy.ai/th/mcp#client=codex&mode=agent)
- [Official Meshy MCP server](https://github.com/meshy-dev/meshy-mcp-server)
- [Codex MCP configuration](https://developers.openai.com/codex/mcp)


## Reviewed torso/head motion overlay

`retarget_meshy_overlay.py` accepts an existing Meshy motion GLB and an approved
game GLB, appending replacement animation accessors while preserving model/skin
and other animation bytes. Supported clip profiles: Idle, Talk, Scan; 0.15 local
rotation gain, 12° output envelope, approved limbs/root retained. This does not
transfer full-body gait, fingers or exact tool motion. Run `check_candidate_clips.gd`,
`tests/test_v31_candidates.gd` (normal and slope), contract and equipment tests,
and actual scene review before installing. The first full-body transfer failed;
that experimental profile is not an accepted route.

Current five-identity/six-file delivery and costs:
[asset/game completion handoff](../asset_pipeline/VILLAGE_COMPLETION_HANDOFF_20261003.md).

## Current full motion and skin route

The subsequent user-authorized pass improves all six skins and reviews 34 clips, replacing 22 clip records. `retarget_meshy_motion.py` builds gait/gesture candidates and `refine_skin_weights.py` refines calibrated joint weights. This intentionally changes skin weights, while independently preserving rest geometry/UVs/albedo and named skeleton landmarks. New motion is imported at 60 fps; use matching inspector bake rate. [Current costs, tests and rollback](RIG_ANIMATION_HANDOFF_20261003.md). Earlier preservation statements describe the quiet overlay-only pass.
