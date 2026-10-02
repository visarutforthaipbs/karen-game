# Fire sprite assets — v1.2

Greyscale RGBA; the game supplies colour. Flame: 512×512, 4×4 looping frames,
baselines 8 px from each cell bottom. Smoke: 512×512, 2×2 static variants.
Ember: 64×64. All have alpha and transparent margins.

Generated with the built-in imagegen tool; originals, prompt briefs and SHA-256
hashes are retained in `artifacts/asset_update_v12/image_provenance.json` and
`vfx/source/`. Technical export: `tools/asset_pipeline/export_v12_vfx.gd`.
Validation, live-material reviews and install test log: `artifacts/asset_update_v12/vfx/`.
See `tools/asset_pipeline/V12_ASSET_HANDOFF.md` for delivery evidence.


## 2026-10-02 polish

Flame replaced with broader neutral cores. Mist (`mist_sheet.png`, 512px 2×2)
and ash (`ash_flake.png`, 64px) are now installed on the existing douse hooks.
Smoke and ember retain the earlier files. Current generated originals and exact
prompts: `artifacts/asset_polish_20261002/vfx/source/` and `vfx/prompts.json`.
Packing/validation: `export_polish_vfx.gd`, `validate_polish_vfx.gd`.
Installed hashes and live day/inversion/night/douse reviews are under
`artifacts/asset_polish_20261002/vfx/`.
See `tools/asset_pipeline/ASSET_POLISH_HANDOFF_20261002.md`.
