"""Check exported game geometry and embedded textures; this is not a likeness score."""
import argparse
import json
from pathlib import Path
import numpy as np
import trimesh


def validate(path, height, faces, texture_size):
    scene = trimesh.load(path, force='scene', process=False)
    meshes = scene.dump()
    if not len(meshes):
        raise ValueError('No geometry in candidate')
    triangles = sum(len(mesh.faces) for mesh in meshes)
    finite = all(np.isfinite(mesh.vertices).all() for mesh in meshes)
    zero_area = sum(int(np.count_nonzero(mesh.area_faces <= 0)) for mesh in meshes)
    textures = []
    uv_valid = True
    for mesh in meshes:
        uv = getattr(mesh.visual, 'uv', None)
        uv_valid &= uv is not None and len(uv) == len(mesh.vertices) and bool(np.isfinite(uv).all())
        material = getattr(mesh.visual, 'material', None)
        texture = getattr(material, 'baseColorTexture', None)
        if texture is None:
            raise ValueError('Every surface must have an embedded base-colour texture')
        textures.append(list(texture.size))
    measured_height = float(scene.extents[1])
    ground = float(scene.bounds[0, 1])
    passed = bool(finite and uv_valid and zero_area == 0 and 0 < triangles <= faces
                  and abs(measured_height - height) <= 0.005 and abs(ground) <= 0.005
                  and all(t == [texture_size, texture_size] for t in textures))
    return {'passed': passed, 'triangles': triangles, 'height_m': measured_height,
            'ground_y': ground, 'finite': bool(finite), 'zero_area': zero_area,
            'valid_uvs': bool(uv_valid), 'textures': textures, 'visual_review': 'required'}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('input', type=Path)
    parser.add_argument('--height', type=float, required=True)
    parser.add_argument('--faces', type=int, required=True)
    parser.add_argument('--texture-size', type=int, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    result = validate(args.input, args.height, args.faces, args.texture_size)
    args.output.write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(result))
    if not result['passed']:
        raise SystemExit('Candidate failed technical validation')


if __name__ == '__main__':
    main()
