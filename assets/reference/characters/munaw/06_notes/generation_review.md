# Mu-naw v3.1 generation notes

Date: 2026-10-02. Image references generated with the built-in imagegen tool.
Prompts retained in `apose_v01_prompt.txt` and `apose_v02_prompt.txt`.

## Production input review

- v01 rejected before 3D generation: approximately four heads tall, outside the cast's 2.5–3-head style range.
- v02 selected for candidate generation: approximately 2.8 heads by visual crown/chin/sole measurement; within the cast range, slightly taller than nominal 2.6. Face, white/red garment, low-poly planes and boots remain consistent with supplied concept.
- Both hands clear of body, thumb gaps visible, boots and lower legs separate. Hair tail may approach the shoulder and needs 3D inspection.
- Body-only input deliberately omits equipment so the old fused hose/hand geometry is not repeated.
- This is an art-direction/geometry experiment, not verified portrait likeness or cultural approval.

## Candidate

`artifacts/character_candidates/munaw_hinladnai_v01/run.json` is the authoritative build status and recipe record.

Review before rigging: front/three-quarter/side/back face and hair volume; hands;
continuous restrained garment bands; real geometry facets vs painted triangles;
lower-leg separation; hem thickness/opening; shape at gameplay distance.
Inspect both cached-material and fresh-texture outputs: a fresh texture pass is
not automatically better.

Final production remains pending cultural reference verification and a newly
calibrated dress rig with movement/deformation evidence.

## Completed first candidate review

- Source generation, repair and fresh texture completed successfully. 39,798 triangles, 1.10 m, valid UVs and embedded 2048×2048 base color, no zero-area faces.
- Godot Forward+ Metal four-view renders: `flat_review.png` and `style_review.png` in the candidate folder.
- Preferred exploration: `candidate/munaw_hinladnai_v01_flat40000.glb`, with flat normals, roughness 1, metallic 0 and no normal-map smoothing. This is not production approval.
- Fresh texture improves eyes and red-band continuity relative to cached material. Dress, short proportions and separated lower legs are readable.
- Rejected 11,938-triangle variant: technical checks passed, but decimation badly distorts garment stripes and facial UV texture. Future topology changes must rebake texture before acceptance.
- Still needs hair/ponytail texture and surface cleanup, hem/fringe cleanup, finger-detail review, garment-interior inspection and calibrated deformation tests. Facets remain finer than the concept.
- No new model installed or rigged. Full review, hashes and variant decisions: `review.json` in the candidate folder.
