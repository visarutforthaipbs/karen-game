"""CPU screened-Poisson candidate from an oriented exterior point cloud.

Requires PyMeshLab, NumPy and trimesh. Use an isolated tool environment. No
texture/rig is produced and no production model is installed by this command.
"""
import argparse
import hashlib
import importlib.metadata
import json
from pathlib import Path

import numpy as np
import pymeshlab
import trimesh


def reconstruct(source, destination, depth=8):
    source, destination = Path(source), Path(destination)
    if destination.suffix != '.ply' or destination.exists() or destination.with_suffix('.json').exists():
        raise ValueError('Use a new .ply output; preserve prior candidates')
    if depth not in (7, 8, 9):
        raise ValueError('Supported depths: 7, 8, 9')
    with np.load(source, allow_pickle=False) as samples:
        vertices = np.asarray(samples['vertices'], dtype=np.float64)
        normals = np.asarray(samples['normals'], dtype=np.float64)
    if (vertices.ndim != 2 or vertices.shape[1] != 3 or normals.shape != vertices.shape
            or len(vertices) < 100 or not np.isfinite(vertices).all()
            or not np.isfinite(normals).all()):
        raise ValueError('Expected at least 100 finite oriented 3D points')
    lengths = np.linalg.norm(normals, axis=1)
    if np.any(lengths < 1e-8):
        raise ValueError('Zero-length sample normals')
    normals /= lengths[:, None]
    meshes = pymeshlab.MeshSet()
    meshes.add_mesh(pymeshlab.Mesh(vertex_matrix=vertices, v_normals_matrix=normals), 'Exterior')
    meshes.generate_surface_reconstruction_screened_poisson(
        depth=depth, pointweight=2, samplespernode=2, threads=12)
    result = meshes.current_mesh()
    mesh = trimesh.Trimesh(result.vertex_matrix(), result.face_matrix(), process=False)
    if not len(mesh.faces) or not np.isfinite(mesh.vertices).all():
        raise ValueError('Reconstruction returned invalid geometry')
    # repair=False is deliberate: trimesh must not silently fill holes during assessment.
    components = sorted(mesh.split(only_watertight=False, repair=False),
                        key=lambda part: len(part.faces), reverse=True)
    destination.parent.mkdir(parents=True, exist_ok=True)
    components[0].export(destination)
    report = {'input_sha256': hashlib.sha256(source.read_bytes()).hexdigest(),
              'pymeshlab_version': importlib.metadata.version('pymeshlab'),
              'depth': depth, 'pointweight': 2, 'samplespernode': 2,
              'kept_component': 0,
              'discarded_components': len(components) - 1,
              'components': [{'triangles': len(c.faces), 'watertight': bool(c.is_watertight),
                              'euler': int(c.euler_number)} for c in components],
              'bounds': components[0].bounds.tolist(),
              'max_bound_extension_m': float(max(0,
                  np.max(vertices.min(0) - components[0].bounds[0]),
                  np.max(components[0].bounds[1] - vertices.max(0)))),
              'visual_review': 'required',
              'rigged': False, 'installed': False}
    destination.with_suffix('.json').write_text(json.dumps(report, indent=2) + '\n')
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('input', type=Path)
    parser.add_argument('output', type=Path)
    parser.add_argument('--depth', type=int, choices=(7, 8, 9), default=8)
    args = parser.parse_args()
    print(json.dumps(reconstruct(args.input, args.output, args.depth)), flush=True)


if __name__ == '__main__':
    main()
