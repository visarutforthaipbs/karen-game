# Steam QA and release checklist

All boxes below require evidence from the stated release candidate. A locally passing engine test does not establish native Windows/Linux compatibility or player understanding.

## Demo/full boundary

- [ ] Demo identity/build flag is explicit and cannot be toggled through ordinary saved settings.
- [ ] Five Year 1 plots can complete; harvest result appears before the Year 2 block.
- [ ] Continue/reload/reinstall cannot open Year 2 in the demo.
- [ ] Demo replay works; famine/crackdown endings remain coherent.
- [ ] Demo save/settings/records/log directory is separate from full/beta; legacy save migration cannot import full-progress saves accidentally.
- [ ] Full campaign still advances to Year 2+; demo changes do not alter full-game balance.
- [ ] End screen store link uses a verified App ID; no fake wishlist action.

## Gameplay and platforms

- [ ] Fresh Thai players explain both goals, water refill and breath/cough states without coaching.
- [ ] PF spray/refill/warning fixes verified by fresh players, including headphone listening.
- [ ] Reviewed English: menus, tutorial, HUD, village, endings, radio subtitles and all dynamic strings.
- [ ] Long English/Thai strings fit at minimum supported resolution; keyboard focus usable.
- [ ] Native Windows installation, keyboard/gamepad, save/load and Alt+F4 tested.
- [ ] Native Mac notarized installation, save/load, keyboard/gamepad and Command+Q/W tested.
- [ ] Native Linux tested before advertising it; Steam Deck tested before a compatibility claim.
- [ ] Representative minimum hardware measured, with specs/resolution/settings, average and worst-case frame behaviour.
- [ ] Multi-year save, backup recovery, existing beta rename migration and reinstall/update tested.
- [ ] No network: campaign runs and board failure gives a usable fallback; settings default opt-in behaviour verified.
- [ ] Clean Steam account install, demo/full switching, update and uninstall behaviour tested.

## Release operations

- [ ] Exact commit, platform payload hash, export version and Steam Build IDs recorded.
- [ ] Staging excludes pipeline references, internal docs/artifacts and credentials; exported resource contents reviewed, not just ZIP file names.
- [ ] Asset commercial evidence and cultural review complete; AI/content survey accurate.
- [ ] Store features, language columns, screenshots and trailer match candidate.
- [ ] Price/regional prices/discount confirmed in actual dashboard.
- [ ] Valve page/build approval and account timing requirements satisfied.
- [ ] Support contact tested; release/hotfix owner and seven-day availability assigned.
- [ ] Known issues written clearly; no crash/save-loss blocker remains.
- [ ] Private test branch verified; public release is a deliberate owner action.

Store evidence under a release-specific directory with date, build, platform/device, steps, expected/actual result and screenshots/logs. Follow AGENT.md for every GDScript/scene edit. Required engine smoke: `godot --headless --path . --fixed-fps 60 --quit-after 120`. Keep demo/save-isolation and platform tests meaningful; do not replace native-machine QA with synthetic assertions.
