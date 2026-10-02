#!/usr/bin/env python3
"""Independently compare reviewed source geometry/UVs/albedo with a rig export.

Allows node/vertex reordering and split normals, but not a changed surface.
Usage: verify_rig_preservation.py source.glb rigged.glb report.json
"""
from collections import Counter
import hashlib
import json
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'asset_pipeline'))
from validate_assets import read_glb, accessor, IDENTITY, multiply, node_matrix, transform


def surface(path):
    doc, binary = read_glb(path)
    triangles = Counter()
    images = set()
    def visit(index, parent):
        node = doc['nodes'][index]
        matrix = multiply(parent, node_matrix(node))
        if 'mesh' in node:
            for primitive in doc['meshes'][node['mesh']]['primitives']:
                attrs = primitive['attributes']
                positions = [transform(matrix, p) for p in accessor(doc, binary, attrs['POSITION'])]
                uv = accessor(doc, binary, attrs['TEXCOORD_0'])
                vertices = [tuple(round(v, 5) for v in (*p, *t)) for p, t in zip(positions, uv)]
                indices = [r[0] for r in accessor(doc, binary, primitive['indices'])]
                for offset in range(0, len(indices), 3):
                    triangles[tuple(sorted(vertices[i] for i in indices[offset:offset+3]))] += 1
                material = doc['materials'][primitive['material']]
                texture = material['pbrMetallicRoughness']['baseColorTexture']['index']
                image = doc['images'][doc['textures'][texture]['source']]
                view = doc['bufferViews'][image['bufferView']]
                offset = view.get('byteOffset', 0)
                images.add(hashlib.sha256(binary[offset:offset+view['byteLength']]).hexdigest())
        for child in node.get('children', []): visit(child, matrix)
    for node in doc['scenes'][doc.get('scene', 0)]['nodes']: visit(node, IDENTITY)
    return triangles, images


if __name__ == '__main__':
    source, rig, report = map(Path, sys.argv[1:])
    before, before_images = surface(source)
    after, after_images = surface(rig)
    result = dict(source=str(source), rig=str(rig),
                  source_sha256=hashlib.sha256(source.read_bytes()).hexdigest(),
                  rig_sha256=hashlib.sha256(rig.read_bytes()).hexdigest(),
                  triangles=sum(before.values()),
                  geometry_and_uvs_match=before == after,
                  albedo_bytes_match=before_images == after_images,
                  coordinate_decimal_places=5)
    result['passed'] = result['geometry_and_uvs_match'] and result['albedo_bytes_match']
    report.write_text(json.dumps(result, indent=2)+'\n')
    print(json.dumps(result, indent=2))
    sys.exit(0 if result['passed'] else 1)
