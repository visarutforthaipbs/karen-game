#!/usr/bin/env python3
"""
Validate generated character assets against tools/character_pipeline/character_specifications.md.

Checks per character:
  - GLB exists, has POSITION + COLOR_0, triangle/vertex counts match the registry
  - OBJ matches the GLB counts
  - Feet grounded at Y=0, X/Z centered, height matches the spec
  - No zero-area triangles, no unreferenced vertices
  - Reports sliver triangles as warnings (does not fail)

Usage:
  python3 tools/character_pipeline/validate_character_assets.py
  python3 tools/character_pipeline/validate_character_assets.py --root /path/to/project
"""

from __future__ import annotations

import argparse
import json
import struct
import sys
from pathlib import Path

# Registry mirror of character_specifications.md / PIPELINE_DASHBOARD.md
REGISTRY = {
    "khanae": {"tris": 2498, "verts": 1253, "height": 1.20},
    "tapoh": {"tris": 2497, "verts": 1252, "height": 1.15},
    "munaw": {"tris": 2498, "verts": 1249, "height": 1.10},
}

HEIGHT_TOL = 0.005
CENTER_TOL = 0.02
ZERO_AREA = 1e-12
SLIVER_AREA = 1e-6


def parse_obj(path: Path):
    verts = []
    faces = []
    with path.open() as f:
        for line in f:
            if line.startswith("v "):
                parts = line.split()
                verts.append([float(parts[1]), float(parts[2]), float(parts[3])])
            elif line.startswith("f "):
                idx = [int(t.split("/")[0]) - 1 for t in line.split()[1:]]
                if len(idx) == 3:
                    faces.append(idx)
                else:
                    for i in range(1, len(idx) - 1):
                        faces.append([idx[0], idx[i], idx[i + 1]])
    return verts, faces


def parse_glb(path: Path):
    data = path.read_bytes()
    magic, _ver, length = struct.unpack_from("<4sII", data, 0)
    if magic != b"glTF":
        raise ValueError(f"not a GLB file: {path}")
    off = 12
    gltf = None
    while off < length:
        clen, ctype = struct.unpack_from("<I4s", data, off)
        off += 8
        chunk = data[off : off + clen]
        off += clen
        if ctype == b"JSON":
            gltf = json.loads(chunk.decode("utf-8"))
    if gltf is None:
        raise ValueError(f"GLB missing JSON chunk: {path}")

    prim = gltf["meshes"][0]["primitives"][0]
    attrs = prim.get("attributes", {})
    idx_acc = gltf["accessors"][prim["indices"]] if "indices" in prim else None
    pos_acc = gltf["accessors"][attrs["POSITION"]]
    tris = (idx_acc["count"] // 3) if idx_acc else pos_acc["count"] // 3
    return {
        "attrs": sorted(attrs),
        "tris": tris,
        "verts": pos_acc["count"],
    }


def triangle_areas(verts, faces):
    areas = []
    for a, b, c in faces:
        ax, ay, az = verts[a]
        bx, by, bz = verts[b]
        cx, cy, cz = verts[c]
        ab = (bx - ax, by - ay, bz - az)
        ac = (cx - ax, cy - ay, cz - az)
        cr = (
            ab[1] * ac[2] - ab[2] * ac[1],
            ab[2] * ac[0] - ab[0] * ac[2],
            ab[0] * ac[1] - ab[1] * ac[0],
        )
        areas.append(0.5 * (cr[0] * cr[0] + cr[1] * cr[1] + cr[2] * cr[2]) ** 0.5)
    return areas


def check_character(root: Path, name: str, spec: dict):
    errors = []
    warnings = []
    glb = root / "assets" / "models" / f"{name}_lowpoly.glb"
    obj = root / "assets" / "models" / f"{name}_lowpoly.obj"

    for p in (glb, obj):
        if not p.exists():
            errors.append(f"{name}: missing file {p.relative_to(root)}")
            return errors, warnings

    try:
        g = parse_glb(glb)
    except Exception as exc:
        errors.append(f"{name}: GLB parse failed: {exc}")
        return errors, warnings

    verts, faces = parse_obj(obj)

    if "COLOR_0" not in g["attrs"]:
        errors.append(f"{name}: GLB missing COLOR_0 vertex colors (got {g['attrs']})")

    if g["tris"] != spec["tris"]:
        errors.append(f"{name}: GLB tris {g['tris']} != registry {spec['tris']}")
    if g["verts"] != spec["verts"]:
        errors.append(f"{name}: GLB verts {g['verts']} != registry {spec['verts']}")
    if len(faces) != g["tris"]:
        errors.append(f"{name}: OBJ tris {len(faces)} != GLB {g['tris']}")
    if len(verts) != g["verts"]:
        errors.append(f"{name}: OBJ verts {len(verts)} != GLB {g['verts']}")

    ys = [v[1] for v in verts]
    xs = [v[0] for v in verts]
    zs = [v[2] for v in verts]
    height = max(ys) - min(ys)

    if abs(min(ys)) > HEIGHT_TOL:
        errors.append(f"{name}: feet not grounded (y_min={min(ys):.4f})")
    if abs(height - spec["height"]) > HEIGHT_TOL:
        errors.append(f"{name}: height {height:.4f} != registry {spec['height']}")
    if abs(max(xs) + min(xs)) / 2 > CENTER_TOL:
        errors.append(f"{name}: X not centered (center={(max(xs) + min(xs)) / 2:.4f})")
    if abs(max(zs) + min(zs)) / 2 > CENTER_TOL:
        errors.append(f"{name}: Z not centered (center={(max(zs) + min(zs)) / 2:.4f})")

    areas = triangle_areas(verts, faces)
    degen = sum(1 for a in areas if a < ZERO_AREA)
    slivers = sum(1 for a in areas if ZERO_AREA <= a < SLIVER_AREA)
    if degen:
        errors.append(f"{name}: {degen} zero-area triangle(s)")
    if slivers:
        warnings.append(f"{name}: {slivers} sliver triangle(s) (area < {SLIVER_AREA:g})")

    used = {i for f in faces for i in f}
    if len(used) != len(verts):
        errors.append(f"{name}: {len(verts) - len(used)} unreferenced vertices")

    return errors, warnings


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--root",
        default=str(Path(__file__).resolve().parents[2]),
        help="Project root containing assets/models (default: repo root)",
    )
    args = parser.parse_args()
    root = Path(args.root)

    all_errors: list[str] = []
    all_warnings: list[str] = []
    for name, spec in REGISTRY.items():
        errors, warnings = check_character(root, name, spec)
        status = "OK" if not errors else f"FAIL ({len(errors)})"
        print(f"  {name:8s}  tris={spec['tris']:<5} verts={spec['verts']:<5} h={spec['height']:.2f}m  {status}")
        all_errors.extend(errors)
        all_warnings.extend(warnings)

    if all_warnings:
        print("\nWarnings:")
        for w in all_warnings:
            print(f"  - {w}")

    if all_errors:
        print("\nIssues:")
        for e in all_errors:
            print(f"  - {e}")
        return 1

    print(f"\nAll {len(REGISTRY)} character assets match the registry.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
