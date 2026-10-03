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

Storage: Cloudflare R2 bucket **undertwoskies-beta**, account **37985e3dbd0d5cc809f4740dec81dbfc** (Under Two Skies - Game, owner visarut298@gmail.com). Existing beta 1 archives are under `beta1/`. Beta 2 is published under `beta2/` with the same three platform filenames and `SHA256SUMS.txt`. Authenticate Wrangler separately from Cloudflare MCP and verify this exact account before upload or deploy.

Built game source: `3964d386857806876b8d4c1a31db41805ca2419e`; artifacts: `build/20261003-3964d38/`. The uploaded Mac filename is `UnderTwoSkies-macOS.zip` but its contents must come from the **-notarized.zip** output, never the unnotarized export. Only announce the new beta on the promotion site after all downloads and checksum responses are verified. Keep old versioned objects for rollback.

## Published verification — 2026-10-03

Cloudflare MCP and Wrangler both verified owner `visarut298@gmail.com` and the intended game account. All three beta 2 ZIPs were uploaded to R2 and streamed back in full through the public download Worker; byte lengths and SHA-256 hashes match `build/20261003-3964d38/SHA256SUMS.txt`. HEAD and byte-range downloads pass, and the beta 1 Windows link remains available. Evidence: `artifacts/release_beta2_20261003/live_download_verification.json`.

Download Worker version: `c60cd882-8adf-49d6-bf61-bca824a76266`. The notarized Mac archive is served as `beta2/UnderTwoSkies-macOS.zip`. Promotion repository commit `92f7874` was pushed after installer verification; its enabled GitHub Actions production workflow deploys future main-branch changes automatically.

The promotion site is live at beta 2 in English and Thai, manually deployed as Worker version `0e7ff691-2be7-4d5d-87a1-ad4489cb3f7b`. GitHub deployment run `37111096657` failed because its saved Cloudflare token is invalid (9109). Automatic deployment remains blocked until that secret is replaced; a game-account-only Workers Scripts: Edit token is prepared for confirmation in the Cloudflare dashboard. No token values are recorded here.
