"""Blender: sample visible outward-facing surfaces for candidate reconstruction.

Example: blender -b --python-exit-code 1 -P sample_outer_surface.py --
  --input character.glb --output exterior.npz

Use a ground-aligned, metre-scale character. Hidden walls and back-facing hits
are excluded. This is a geometry experiment, not a visual acceptance gate.
"""
import argparse
import hashlib
import itertools
import json
from pathlib import Path
import sys

import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree
import numpy as np


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--input', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--spacing', type=float, default=.003, help='Ray-grid spacing in metres')
    args = parser.parse_args(sys.argv[sys.argv.index('--') + 1:])
    if not .001 <= args.spacing <= .02:
        parser.error('Spacing must be between 1 mm and 20 mm')
    if args.output.suffix != '.npz' or args.output.exists() or args.output.with_suffix('.json').exists():
        parser.error('Use a new .npz output; preserve prior candidates')
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(args.input.resolve()))
    vertices, faces = [], []
    for obj in bpy.context.scene.objects:
        if obj.type != 'MESH':
            continue
        obj.data.calc_loop_triangles()
        offset = len(vertices)
        vertices.extend(obj.matrix_world @ v.co for v in obj.data.vertices)
        faces.extend(tuple(offset + i for i in t.vertices) for t in obj.data.loop_triangles)
    coords = np.asarray(vertices)
    if not faces or not np.isfinite(coords).all():
        raise ValueError('Expected finite triangle geometry')
    extent = coords.max(0) - coords.min(0)
    if not .5 <= extent[2] <= 3:
        raise ValueError('Expected a metre-scale character 0.5–3 m tall; normalize before sampling')
    bvh = BVHTree.FromPolygons(vertices, faces, all_triangles=True)
    center = Vector((coords.min(0) + coords.max(0)) * .5)
    radius = float(np.linalg.norm(extent) * .6)
    points, normals = [], []
    rejected = 0
    for xyz in itertools.product((-1, 0, 1), repeat=3):
        if xyz == (0, 0, 0):
            continue
        direction = Vector(xyz).normalized()
        up = Vector((0, 0, 1)) if abs(direction.z) < .9 else Vector((0, 1, 0))
        right = direction.cross(up).normalized()
        up = right.cross(direction).normalized()
        origin = center + direction * radius * 2
        horizontal = (coords - center) @ np.asarray(right)
        vertical = (coords - center) @ np.asarray(up)
        for x in np.arange(horizontal.min(), horizontal.max() + args.spacing, args.spacing):
            for y in np.arange(vertical.min(), vertical.max() + args.spacing, args.spacing):
                point, normal, _, _ = bvh.ray_cast(
                    origin + right * float(x) + up * float(y), -direction, radius * 4)
                if point is None:
                    continue
                if normal.dot(direction) < .2:
                    rejected += 1
                    continue
                points.append(tuple(point))
                normals.append(tuple(normal))
    if len(points) < 100:
        raise ValueError('Insufficient exterior samples; check normals and scale')
    points = np.asarray(points, dtype=np.float32)
    normals = np.asarray(normals, dtype=np.float32)
    # Equalize density without averaging across sharp surface boundaries.
    _, indices = np.unique(np.round(points / (args.spacing * .5)).astype(np.int32),
                           axis=0, return_index=True)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open('xb') as stream:
        np.savez_compressed(stream, vertices=points[indices], normals=normals[indices])
    report = {'input_sha256': hashlib.sha256(args.input.read_bytes()).hexdigest(),
              'spacing_m': args.spacing, 'view_count': 26, 'samples': len(indices),
              'backface_hits_rejected': rejected, 'coordinates': 'Blender Z up, metres',
              'bounds': [points.min(0).tolist(), points.max(0).tolist()],
              'visual_review': 'required'}
    args.output.with_suffix('.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report), flush=True)


if __name__ == '__main__':
    main()
