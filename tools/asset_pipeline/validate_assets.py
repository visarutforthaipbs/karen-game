#!/usr/bin/env python3
"""Validate self-contained static GLBs in world space. No third-party dependencies."""
import argparse
import json
import math
import re
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PROPS = ROOT / 'assets/props'
MANIFEST = Path(__file__).with_name('asset_manifest.json')
NAME_RE = re.compile(r'^([A-Z]\d+)_([a-z0-9_]+)_([a-z])\.glb$')
FORMATS = {5120: 'b', 5121: 'B', 5122: 'h', 5123: 'H', 5125: 'I', 5126: 'f'}
WIDTHS = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4, 'MAT4': 16}
IDENTITY = [1.,0,0,0, 0,1.,0,0, 0,0,1.,0, 0,0,0,1.]


def read_glb(path):
    data = Path(path).read_bytes()
    if len(data) < 20 or struct.unpack_from('<4sII', data) != (b'glTF', 2, len(data)):
        raise ValueError('Invalid GLB header/version/length')
    offset, document, binary = 12, None, None
    while offset < len(data):
        if offset+8 > len(data):
            raise ValueError('Truncated GLB chunk')
        size, kind = struct.unpack_from('<II', data, offset)
        if size % 4 or offset+8+size > len(data):
            raise ValueError('Invalid GLB chunk size')
        chunk = data[offset+8:offset+8+size]
        if kind == 0x4e4f534a:
            if document is not None:
                raise ValueError('Duplicate GLB JSON')
            document = json.loads(chunk)
        elif kind == 0x004e4942:
            if binary is not None:
                raise ValueError('Duplicate GLB buffer')
            binary = chunk
        offset += 8+size
    if not isinstance(document, dict) or binary is None:
        raise ValueError('GLB requires JSON and embedded buffer')
    buffers = document.get('buffers', [])
    if len(buffers) != 1 or 'uri' in buffers[0] or not 0 <= len(binary)-buffers[0]['byteLength'] <= 3:
        raise ValueError('Expected one self-contained GLB buffer')
    return document, binary


def accessor(doc, binary, index):
    if not isinstance(index, int) or not 0 <= index < len(doc['accessors']):
        raise ValueError('Invalid accessor index')
    acc = doc['accessors'][index]
    if 'sparse' in acc:
        raise ValueError('Sparse accessors must be expanded before validation')
    view = doc['bufferViews'][acc['bufferView']]
    if view.get('buffer', 0) != 0:
        raise ValueError('External buffer is unsupported')
    fmt = '<' + FORMATS[acc['componentType']] * WIDTHS[acc['type']]
    width = struct.calcsize(fmt)
    stride = view.get('byteStride', width)
    start = view.get('byteOffset', 0)+acc.get('byteOffset', 0)
    end = view.get('byteOffset', 0)+view['byteLength']
    count = acc['count']
    if (count < 1 or stride < width or start < 0 or end > len(binary)
            or start+(count-1)*stride+width > end):
        raise ValueError('Accessor exceeds its buffer view')
    values = [struct.unpack_from(fmt, binary, start+i*stride) for i in range(count)]
    if not all(math.isfinite(x) for row in values for x in row):
        raise ValueError('Non-finite accessor values')
    return values


def multiply(a, b):
    return [sum(a[k*4+r]*b[c*4+k] for k in range(4)) for c in range(4) for r in range(4)]


def node_matrix(node):
    if 'matrix' in node:
        values = node['matrix']
        if len(values) != 16 or not all(math.isfinite(x) for x in values):
            raise ValueError('Invalid node matrix')
        if any(abs(values[i]) > 1e-8 for i in (3, 7, 11)) or abs(values[15]-1) > 1e-8:
            raise ValueError('Node transform is not affine')
        return values
    x, y, z, w = node.get('rotation', [0,0,0,1])
    if abs(x*x+y*y+z*z+w*w-1) > .001:
        raise ValueError('Invalid node quaternion')
    scale = node.get('scale', [1,1,1]); t = node.get('translation', [0,0,0])
    r = [1-2*(y*y+z*z), 2*(x*y+z*w), 2*(x*z-y*w), 0,
         2*(x*y-z*w), 1-2*(x*x+z*z), 2*(y*z+x*w), 0,
         2*(x*z+y*w), 2*(y*z-x*w), 1-2*(x*x+y*y), 0, *t, 1]
    for c in range(3):
        for row in range(3):
            r[c*4+row] *= scale[c]
    if not all(math.isfinite(v) for v in r):
        raise ValueError('Non-finite transform')
    return r


def transform(m, p):
    return tuple(sum(m[c*4+r]*p[c] for c in range(3))+m[12+r] for r in range(3))


def inspect(path):
    doc, binary = read_glb(path)
    if doc.get('skins') or doc.get('animations'):
        raise ValueError('Static prop pipeline does not flatten skins or animation')
    if doc.get('extensionsRequired'):
        raise ValueError('Bake required extensions before static prop validation')
    counts = {'tris': 0, 'surfaces': 0, 'zero_area': 0, 'textured_surfaces': 0,
              'colored_surfaces': 0, 'solid_surfaces': 0}
    mins, maxs = [float('inf')]*3, [-float('inf')]*3
    cache = {}

    def read(index):
        if index not in cache:
            cache[index] = accessor(doc, binary, index)
        return cache[index]

    def visit(index, parent, ancestors):
        if index in ancestors or not 0 <= index < len(doc.get('nodes', [])):
            raise ValueError('Invalid or cyclic scene graph')
        node = doc['nodes'][index]
        matrix = multiply(parent, node_matrix(node))
        if 'mesh' in node:
            mesh = doc['meshes'][node['mesh']]
            for primitive in mesh['primitives']:
                if primitive.get('mode', 4) != 4 or primitive.get('targets'):
                    raise ValueError('Only static triangle primitives are supported')
                attrs = primitive['attributes']
                pos = doc['accessors'][attrs['POSITION']]
                if pos['type'] != 'VEC3' or pos['componentType'] != 5126:
                    raise ValueError('Positions must be float32 VEC3')
                vertices = [transform(matrix, v) for v in read(attrs['POSITION'])]
                if not all(math.isfinite(x) for v in vertices for x in v):
                    raise ValueError('Non-finite transformed geometry')
                if 'indices' in primitive:
                    idx = doc['accessors'][primitive['indices']]
                    if idx['type'] != 'SCALAR' or idx['componentType'] not in (5121,5123,5125):
                        raise ValueError('Invalid index accessor')
                    indices = [v[0] for v in read(primitive['indices'])]
                else:
                    indices = list(range(len(vertices)))
                if len(indices) % 3 or not indices or min(indices) < 0 or max(indices) >= len(vertices):
                    raise ValueError('Invalid triangle indices')
                counts['surfaces'] += 1
                counts['tris'] += len(indices)//3
                for i in set(indices):
                    for k in range(3):
                        mins[k] = min(mins[k], vertices[i][k]); maxs[k] = max(maxs[k], vertices[i][k])
                for i in range(0, len(indices), 3):
                    a,b,c = (vertices[j] for j in indices[i:i+3])
                    u = [b[k]-a[k] for k in range(3)]; v = [c[k]-a[k] for k in range(3)]
                    cross = [u[1]*v[2]-u[2]*v[1], u[2]*v[0]-u[0]*v[2], u[0]*v[1]-u[1]*v[0]]
                    if sum(x*x for x in cross) <= 1e-24:
                        counts['zero_area'] += 1
                if 'COLOR_0' in attrs:
                    colors = read(attrs['COLOR_0'])
                    if len(colors) != len(vertices) or len(colors[0]) not in (3,4):
                        raise ValueError('Invalid colour coverage')
                    counts['colored_surfaces'] += 1
                material = doc.get('materials', [])[primitive['material']] if 'material' in primitive else {}
                pbr = material.get('pbrMetallicRoughness', {})
                if 'baseColorTexture' in pbr:
                    texture = pbr['baseColorTexture']
                    uv = read(attrs['TEXCOORD_'+str(texture.get('texCoord', 0))])
                    if len(uv) != len(vertices) or len(uv[0]) != 2:
                        raise ValueError('Invalid UV coverage')
                    image = doc['images'][doc['textures'][texture['index']]['source']]
                    if 'uri' in image or 'bufferView' not in image:
                        raise ValueError('Texture must be embedded')
                    view = doc['bufferViews'][image['bufferView']]
                    start = view.get('byteOffset', 0); size = view['byteLength']
                    if size <= 0 or start < 0 or start+size > len(binary):
                        raise ValueError('Invalid embedded image buffer')
                    payload = binary[start:start+size]
                    if not (payload.startswith(b'\x89PNG\r\n\x1a\n') or payload.startswith(b'\xff\xd8')):
                        raise ValueError('Expected embedded PNG/JPEG texture')
                    counts['textured_surfaces'] += 1
                elif 'COLOR_0' not in attrs:
                    color = pbr.get('baseColorFactor')
                    if color is None or len(color) != 4 or not all(math.isfinite(c) and 0 <= c <= 1 for c in color):
                        raise ValueError('Surface has no explicit colour or texture')
                    counts['solid_surfaces'] += 1
        for child in node.get('children', []):
            visit(child, matrix, ancestors | {index})

    scene = doc['scenes'][doc.get('scene', 0)]
    for node in scene['nodes']:
        visit(node, IDENTITY, set())
    if not counts['tris']:
        raise ValueError('No visible triangle geometry')
    return {**counts, 'has_color': counts['colored_surfaces'] > 0, 'min': mins, 'max': maxs}


def check(path, manifest, profile='standard'):
    name = Path(path).name
    match = NAME_RE.fullmatch(name)
    if not match or match[1] not in manifest['assets']:
        return name, ['Expected a known <ID>_<name>_<variant>.glb'], None
    spec = manifest['assets'][match[1]]
    if match[2] != spec['name']:
        return name, ['File name does not match manifest asset name'], None
    try:
        info = inspect(path)
    except (ValueError, KeyError, IndexError, TypeError, struct.error, OSError) as exc:
        return name, [f'Invalid asset: {exc}'], None
    problems = []
    ext = [info['max'][k]-info['min'][k] for k in range(3)]
    budget = spec.get('quality_tris', spec['tris']) if profile == 'quality' else spec['tris']
    if info['tris'] > budget:
        problems.append(f"{info['tris']} tris exceeds strict budget {budget}")
    if info['zero_area']:
        problems.append(f"{info['zero_area']} zero-area triangles")
    fitted = {'height':ext[1], 'width':max(ext[0],ext[2]), 'max':max(ext)}[spec['fit']]
    if abs(fitted-spec['meters']) > spec['meters']*.03:
        problems.append(f"world-space {spec['fit']} {fitted:.3f} m; expected {spec['meters']}")
    if abs(info['min'][1]) > .005:
        problems.append('Not grounded at Y=0 within 5 mm')
    if any(abs(info['min'][k]+info['max'][k])*.5 > max(ext)*.03 for k in (0,2)):
        problems.append('Not centred on X/Z')
    instanced = spec.get('render_mode') == 'vertex'
    if instanced and info['colored_surfaces'] != info['surfaces']:
        problems.append('Instanced vegetation requires vertex colours on every surface')
    if info['surfaces'] > (1 if instanced else 8):
        problems.append('Too many material surfaces for this asset class')
    summary = f"{info['tris']}/{budget} tris; world size {ext}; {info['textured_surfaces']} textured surfaces"
    return name, problems, summary


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('files', nargs='*', type=Path)
    p.add_argument('--profile', choices=['standard','quality'], default='standard')
    args = p.parse_args()
    manifest = json.loads(MANIFEST.read_text())
    files = args.files or sorted(PROPS.glob('*.glb'))
    if not files:
        print('No props found; no assets were validated')
        return 0
    failed = False
    for path in files:
        name, problems, summary = check(path, manifest, args.profile)
        print(('FAIL ' if problems else 'OK   ')+name+': '+('; '.join(problems) if problems else summary))
        failed |= bool(problems)
    return int(failed)


if __name__ == '__main__':
    raise SystemExit(main())
