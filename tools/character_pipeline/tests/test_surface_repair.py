"""Real Blender regression: cap a pinhole but preserve a garment-sized opening."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

import numpy as np
from PIL import Image
import trimesh


@unittest.skipUnless(os.environ.get('BLENDER_BIN'), 'Set BLENDER_BIN for real repair')
class SurfaceRepairTest(unittest.TestCase):
    def test_small_hole_and_debris_only(self):
        small = trimesh.creation.icosphere(subdivisions=3, radius=.1)
        large = trimesh.creation.icosphere(subdivisions=2, radius=.5)
        small.update_faces(np.arange(len(small.faces)) != 0)
        large.update_faces(np.arange(len(large.faces)) != 0)
        large.apply_translation([2, 0, 0])
        debris = trimesh.Trimesh(vertices=[[4, 0, 0], [4.001, 0, 0], [4, .001, 0]],
                                 faces=[[0, 1, 2]], process=False)
        mesh = trimesh.util.concatenate([small, large, debris])
        mesh.visual = trimesh.visual.texture.TextureVisuals(
            uv=np.full((len(mesh.vertices), 2), .5), image=Image.new('RGB', (16, 16), 'red'))
        script = Path(__file__).resolve().parents[1] / 'repair_small_surface_defects.py'
        with tempfile.TemporaryDirectory() as folder:
            folder = Path(folder)
            source, target = folder/'source.glb', folder/'repaired.glb'
            mesh.export(source)
            subprocess.run([os.environ['BLENDER_BIN'], '-b', '--python-exit-code', '1',
                            '-P', str(script), '--', '--input', str(source), '--output',
                            str(target), '--max-hole-perimeter', '.06'],
                           check=True, capture_output=True)
            scene = trimesh.load(target, force='scene', process=False)
            result = trimesh.util.concatenate(scene.dump())
            result.merge_vertices()
            # Trimesh's default split repairs holes itself; inspect without mutation.
            components = sorted(result.split(only_watertight=False, repair=False), key=lambda m: m.centroid[0])
            self.assertEqual(len(components), 2, 'Tiny detached debris remains')
            self.assertTrue(components[0].is_watertight, 'Pinhole was not repaired')
            self.assertFalse(components[1].is_watertight, 'Large intentional opening was capped')
            self.assertEqual(len(components[1].faces), len(large.faces))
            np.testing.assert_allclose(components[1].bounds, large.bounds, atol=1e-6)
            for surface in scene.dump():
                self.assertTrue(np.isfinite(surface.visual.uv).all())
                np.testing.assert_allclose(surface.visual.uv, .5, atol=1e-6)
            report = json.loads(target.with_suffix('.repair.json').read_text())[0]
            self.assertEqual(report['removed_debris_faces'], 1)


if __name__ == '__main__':
    unittest.main()
