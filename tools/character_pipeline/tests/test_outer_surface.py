"""Real reconstruction checks on a known sphere with a missing cap."""
import importlib.util
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

import numpy as np
import trimesh

SCRIPT = Path(__file__).resolve().parents[1] / 'reconstruct_outer_surface.py'
SAMPLER = SCRIPT.with_name('sample_outer_surface.py')


@unittest.skipUnless(importlib.util.find_spec('pymeshlab'), 'Requires isolated PyMeshLab environment')
class OuterSurfaceTest(unittest.TestCase):
    def test_missing_cap_reconstruction_and_input_guards(self):
        spec = importlib.util.spec_from_file_location('outer_reconstruction', SCRIPT)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        sphere = trimesh.creation.icosphere(subdivisions=5)
        points = sphere.vertices[sphere.vertices[:, 2] < .98]
        with tempfile.TemporaryDirectory() as folder:
            folder = Path(folder)
            source, output = folder/'cloud.npz', folder/'sphere.ply'
            np.savez(source, vertices=points, normals=points)
            report = module.reconstruct(source, output, depth=7)
            repaired = trimesh.load(output, process=False)
            self.assertTrue(repaired.is_watertight)
            self.assertEqual(repaired.euler_number, 2)
            # No method can certify the unseen cap from these samples. Check the
            # observed sphere and report extrapolation separately, rather than
            # mistaking watertight output for accurate missing geometry.
            observed = repaired.vertices[repaired.vertices[:, 2] < .9]
            self.assertLess(np.max(np.abs(np.linalg.norm(observed, axis=1) - 1)), .015)
            self.assertGreater(report['max_bound_extension_m'], .02)
            self.assertFalse(report['installed'])
            with self.assertRaisesRegex(ValueError, 'preserve'):
                module.reconstruct(source, output)
            np.savez(source, vertices=points, normals=np.zeros_like(points))
            with self.assertRaisesRegex(ValueError, 'Zero-length'):
                module.reconstruct(source, folder/'invalid.ply')

    @unittest.skipUnless(os.environ.get('BLENDER_BIN'), 'Requires Blender sampling')
    def test_sampler_rejects_back_facing_hits_through_missing_surface(self):
        sphere = trimesh.creation.icosphere(subdivisions=3)
        sphere.update_faces(sphere.triangles_center[:, 1] < .85)
        with tempfile.TemporaryDirectory() as folder:
            folder = Path(folder)
            source, output = folder/'open_sphere.glb', folder/'samples.npz'
            sphere.export(source)
            subprocess.run([os.environ['BLENDER_BIN'], '-b', '--python-exit-code', '1',
                            '-P', str(SAMPLER), '--', '--input', str(source),
                            '--output', str(output), '--spacing', '.02'],
                           check=True, capture_output=True)
            with np.load(output) as samples:
                points, normals = samples['vertices'], samples['normals']
            self.assertGreater(len(points), 1000)
            # Sphere origin is unchanged by the glTF Y-up to Blender Z-up conversion.
            self.assertTrue(np.all(np.einsum('ij,ij->i', points, normals) > .97))
            self.assertLess(np.max(np.abs(np.linalg.norm(points, axis=1) - 1)), .02)


if __name__ == '__main__':
    unittest.main()
