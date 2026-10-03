# Under Two Skies — beta 2 (0.2.0)

2026-10-03. Free Thai playtest update for Windows, macOS and Linux.

- Updated six character rigs and 22 animation clips, including ranger gestures.
- Village Hearth now presents the actual 3D village, characters and furnishings.
- Improved Karen-inspired village houses, granary, equipment and surveillance props.
- Updated Thai voice lines, sound effects, ambience and music transitions.
- Added readable companion water spray, barrel refill guidance and clearer breath recovery guidance.
- Coalesced repeated fire warnings while allowing an urgent forest-fire escalation.
- Added macOS Command+W/Command+Q and Windows/Linux Alt+F4 exit shortcuts, including while paused.

Existing campaign autosaves remain supported. Quitting during a burn resumes at the existing pre-burn save. This update preserves the fire, water and smoke rules.

macOS releases require Developer ID signing, Apple notarization and a stapled ticket. Windows remains unsigned; native Windows/Linux playtest and cultural/Thai listening review remain open. Release artifacts and checksums are published through the existing download website after verification.

## Distribution locations

Promotion site repository: `visarutforthaipbs/undertwoskies-website-promote`, local checkout `/Users/lighthouse-control/Desktop/satellite-shadow-site`.

The promotion site links to **https://undertwoskies-download.undertwoskies-game.workers.dev/**. This download page and the ZIP streaming endpoint are owned by the game repository at `server/download/worker.js` and `server/download/wrangler.toml`.

Storage: Cloudflare R2 bucket **undertwoskies-beta**, account **37985e3dbd0d5cc809f4740dec81dbfc** (Under Two Skies - Game, owner visarut298@gmail.com). Existing beta 1 archives are under `beta1/`. Beta 2 is prepared under `beta2/` with the same three platform filenames and `SHA256SUMS.txt`. Authenticate Wrangler separately from Cloudflare MCP and verify this exact account before upload or deploy.

Built game source: `3964d386857806876b8d4c1a31db41805ca2419e`; artifacts: `build/20261003-3964d38/`. The uploaded Mac filename is `UnderTwoSkies-macOS.zip` but its contents must come from the **-notarized.zip** output, never the unnotarized export. Only announce the new beta on the promotion site after all downloads and checksum responses are verified. Keep old versioned objects for rollback.
