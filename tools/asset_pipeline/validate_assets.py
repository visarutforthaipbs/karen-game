#!/usr/bin/env python3
"""Validate prop GLBs in assets/props against tools/asset_pipeline/asset_manifest.json.

Checks per file: triangle budget, fitted size, origin at base (min Y = 0), centred on X/Z,
vertex colours present. Pure standard library (reads the GLB JSON + binary chunks directly).

Usage:
  python3 tools/asset_pipeline/validate_assets.py              # every prop in assets/props
  python3 tools/asset_pipeline/validate_assets.py <file.glb>   # one file
Exit code 1 if anything fails.
"""
import json
import os
import re
import struct
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
PROPS = os.path.join(ROOT, "assets", "props")
MANIFEST = os.path.join(os.path.dirname(__file__), "asset_manifest.json")
NAME_RE = re.compile(r"^([A-Z]\d+)_[a-z0-9_]+_([a-z])\.glb$")

COMPONENT_SIZE = {5120: 1, 5121: 1, 5122: 2, 5123: 2, 5125: 4, 5126: 4}
TYPE_COUNT = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}


def read_glb(path):
    with open(path, "rb") as f:
        data = f.read()
    magic, _version, _length = struct.unpack_from("<4sII", data, 0)
    if magic != b"glTF":
        raise ValueError("not a GLB file")
    offset = 12
    gltf, binary = None, b""
    while offset < len(data):
        chunk_len, chunk_type = struct.unpack_from("<II", data, offset)
        chunk = data[offset + 8: offset + 8 + chunk_len]
        if chunk_type == 0x4E4F534A:
            gltf = json.loads(chunk)
        elif chunk_type == 0x004E4942:
            binary = chunk
        offset += 8 + chunk_len
    return gltf, binary


def read_positions(gltf, binary, accessor_index):
    acc = gltf["accessors"][accessor_index]
    view = gltf["bufferViews"][acc["bufferView"]]
    start = view.get("byteOffset", 0) + acc.get("byteOffset", 0)
    stride = view.get("byteStride", 12)
    return [struct.unpack_from("<fff", binary, start + i * stride) for i in range(acc["count"])]


def inspect(path):
    gltf, binary = read_glb(path)
    tris, has_color = 0, False
    mins, maxs = [float("inf")] * 3, [float("-inf")] * 3
    for mesh in gltf.get("meshes", []):
        for prim in mesh["primitives"]:
            attrs = prim["attributes"]
            has_color = has_color or "COLOR_0" in attrs
            if "indices" in prim:
                tris += gltf["accessors"][prim["indices"]]["count"] // 3
            else:
                tris += gltf["accessors"][attrs["POSITION"]]["count"] // 3
            for p in read_positions(gltf, binary, attrs["POSITION"]):
                for k in range(3):
                    mins[k] = min(mins[k], p[k])
                    maxs[k] = max(maxs[k], p[k])
    return {"tris": tris, "has_color": has_color, "min": mins, "max": maxs}


def check(path, manifest):
    name = os.path.basename(path)
    m = NAME_RE.match(name)
    problems = []
    if not m:
        return name, ["file name must be <ID>_<name>_<variant>.glb, e.g. S2_water_barrels_a.glb"], None
    spec = manifest["assets"].get(m.group(1))
    if not spec:
        return name, [f"unknown asset ID {m.group(1)}"], None
    info = inspect(path)
    ext = [info["max"][k] - info["min"][k] for k in range(3)]
    if info["tris"] > spec["tris"] * 1.1:
        problems.append(f"{info['tris']} tris > budget {spec['tris']}")
    fitted = {"height": ext[1], "width": max(ext[0], ext[2]), "max": max(ext)}[spec["fit"]]
    if abs(fitted - spec["meters"]) > spec["meters"] * 0.03:
        problems.append(f"{spec['fit']} {fitted:.2f} m, spec {spec['meters']} m")
    if abs(info["min"][1]) > 0.02:
        problems.append(f"base at y={info['min'][1]:.3f}, should be 0")
    for k, axis in ((0, "x"), (2, "z")):
        centre = (info["max"][k] + info["min"][k]) * 0.5
        if abs(centre) > max(ext) * 0.03:
            problems.append(f"not centred on {axis} ({centre:.3f})")
    if not info["has_color"]:
        problems.append("no vertex colours (COLOR_0)")
    summary = f"{info['tris']}/{spec['tris']} tris, {ext[0]:.2f} x {ext[1]:.2f} x {ext[2]:.2f} m"
    return name, problems, summary


def main():
    with open(MANIFEST) as f:
        manifest = json.load(f)
    files = sys.argv[1:]
    if not files and os.path.isdir(PROPS):
        files = sorted(os.path.join(PROPS, n) for n in os.listdir(PROPS) if n.endswith(".glb"))
    if not files:
        print("No props found in assets/props")
        return 0
    failed = 0
    for path in files:
        name, problems, summary = check(path, manifest)
        if problems:
            failed += 1
            print(f"FAIL  {name}: " + "; ".join(problems))
        else:
            print(f"OK    {name}: {summary}")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
