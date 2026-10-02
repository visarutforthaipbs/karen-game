#!/usr/bin/env python3
"""Validate the Meshy replacement contract. Complements real-renderer motion tests.

Usage: validate_meshy_delivery.py manifest.json report.json
Manifest maps character IDs to GLB paths. No third-party dependencies.
"""
import hashlib
import json
import math
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'asset_pipeline'))
from validate_assets import read_glb, accessor, IDENTITY, multiply, node_matrix, transform

HEIGHTS = dict(khanae=1.20, tapoh=1.15, munaw=1.10, maelu=1.15, ranger=1.25)
CORE = {'Root', 'Hips', 'Spine', 'Chest', 'Neck', 'Head', 'Bag'} | {
    part + '.' + side for part in ('UpperArm', 'Forearm', 'Hand', 'Thigh', 'Shin', 'Foot')
    for side in ('L', 'R')}


def inspect(name, path):
    character = name.removesuffix('_slate')
    doc, binary = read_glb(path)
    # Force bounds and finite-value checks for every attribute/animation/skin.
    arrays = [accessor(doc, binary, i) for i in range(len(doc['accessors']))]
    assert len(doc['skins']) == 1, 'Expected exactly one skeleton'
    skin = doc['skins'][0]
    bones = {doc['nodes'][i]['name'] for i in skin['joints']}
    expected = CORE | ({'Skirt.Front', 'Skirt.Back'} if character in ('munaw', 'maelu') else set())
    assert bones == expected, f'Bone contract differs: {bones ^ expected}'
    assert len(arrays[skin['inverseBindMatrices']]) == len(bones)
    clips = {a['name']: a for a in doc['animations']}
    required = {'Idle', 'Walk', 'Run', 'ToolUse'}
    if character == 'maelu': required |= {'Talk', 'Granary'}
    if character == 'ranger': required = {'Idle', 'Walk', 'Run', 'Scan', 'Photograph', 'Point', 'RadioTalk', 'Escort'}
    assert set(clips) == required, 'Animation contract differs'
    durations = {}
    for name_, animation in clips.items():
        durations[name_] = max(arrays[s['input']][-1][0] for s in animation['samplers'])
        assert durations[name_] > 0
        for sampler in animation['samplers']:
            times = [v[0] for v in arrays[sampler['input']]]
            assert all(a < b for a, b in zip(times, times[1:])), 'Unordered animation keys'
    vertices, triangles, surfaces, degenerate = [], 0, 0, 0

    def visit(index, parent, ancestors):
        nonlocal triangles, surfaces, degenerate
        assert index not in ancestors, 'Cyclic scene graph'
        node = doc['nodes'][index]
        matrix = multiply(parent, node_matrix(node))
        if 'mesh' in node:
            assert node.get('skin') == 0
            for primitive in doc['meshes'][node['mesh']]['primitives']:
                assert primitive.get('mode', 4) == 4
                attrs = primitive['attributes']
                pos = [transform(matrix, p) for p in arrays[attrs['POSITION']]]
                uv, weights, joints = (arrays[attrs[k]] for k in ('TEXCOORD_0', 'WEIGHTS_0', 'JOINTS_0'))
                assert len(pos) == len(uv) == len(weights) == len(joints)
                assert all(len(w) == 4 and min(w) >= 0 and abs(sum(w)-1) < 1e-5 for w in weights), 'Invalid normalized skin weights'
                assert all(0 <= j < len(bones) for row in joints for j in row)
                indices = [v[0] for v in arrays[primitive['indices']]]
                assert len(indices) % 3 == 0 and min(indices) >= 0 and max(indices) < len(pos)
                for i in range(0, len(indices), 3):
                    a, b, c = [pos[k] for k in indices[i:i+3]]
                    u, v = [[q[k]-a[k] for k in range(3)] for q in (b, c)]
                    cross = [u[1]*v[2]-u[2]*v[1], u[2]*v[0]-u[0]*v[2], u[0]*v[1]-u[1]*v[0]]
                    degenerate += sum(x*x for x in cross) <= 1e-24
                material = doc['materials'][primitive['material']]
                assert not any(material.get('emissiveFactor', [0, 0, 0])), 'Unwanted emissive material'
                assert 'emissiveTexture' not in material
                pbr = material['pbrMetallicRoughness']
                assert pbr.get('metallicFactor', 1) == 0 and pbr.get('roughnessFactor', 1) >= .8
                image = doc['images'][doc['textures'][pbr['baseColorTexture']['index']]['source']]
                assert 'bufferView' in image and 'uri' not in image
                view = doc['bufferViews'][image['bufferView']]
                start = view.get('byteOffset', 0)
                payload = binary[start:start+view['byteLength']]
                assert payload.startswith((b'\x89PNG\r\n\x1a\n', b'\xff\xd8'))
                vertices.extend(pos); triangles += len(indices)//3; surfaces += 1
        for child in node.get('children', []): visit(child, matrix, ancestors | {index})

    for index in doc['scenes'][doc.get('scene', 0)]['nodes']: visit(index, IDENTITY, set())
    assert triangles <= 20000 and triangles > 0 and degenerate == 0
    lo = [min(v[k] for v in vertices) for k in range(3)]
    hi = [max(v[k] for v in vertices) for k in range(3)]
    assert abs(hi[1]-lo[1]-HEIGHTS[character]) < .002, 'Height changed'
    assert abs(lo[1]) < .001, 'Rest soles not grounded'
    assert all(abs(hi[k]+lo[k]) < .002 for k in (0, 2)), 'Rest bbox not centered'
    return dict(passed=True, triangles=triangles, bones=len(bones), surfaces=surfaces,
                height_m=hi[1]-lo[1], min=lo, max=hi, clips=durations,
                sha256=hashlib.sha256(Path(path).read_bytes()).hexdigest())


if __name__ == '__main__':
    manifest, output = map(Path, sys.argv[1:])
    report = {}
    for name, path in json.loads(manifest.read_text()).items():
        try: report[name] = inspect(name, path)
        except (AssertionError, ValueError, KeyError, IndexError) as exc:
            report[name] = dict(passed=False, error=str(exc))
    output.write_text(json.dumps(report, indent=2)+'\n')
    print(json.dumps(report, indent=2))
    sys.exit(0 if all(r['passed'] for r in report.values()) else 1)
