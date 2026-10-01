"""Exercise real Blender decimation/export and reload embedded UV textures."""
import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path
import numpy as np
import trimesh
from PIL import Image


@unittest.skipUnless(os.environ.get('BLENDER_BIN'), 'Set BLENDER_BIN for integration test')
class TexturedExportTest(unittest.TestCase):
    def test_budget_height_and_embedded_texture(self):
        script = Path(__file__).resolve().parents[1] / 'prepare_textured_character.py'
        mesh = trimesh.creation.icosphere(subdivisions=3)
        v = mesh.vertices
        uv = np.column_stack((np.arctan2(v[:, 2], v[:, 0]) / (2 * np.pi) + .5,
                              np.arcsin(v[:, 1]) / np.pi + .5))
        pixels = np.zeros((16, 16, 3), dtype=np.uint8)
        pixels[:, :8] = [210, 30, 20]
        pixels[:, 8:] = [20, 80, 210]
        mesh.visual = trimesh.visual.texture.TextureVisuals(uv=uv, image=Image.fromarray(pixels))
        with tempfile.TemporaryDirectory(prefix='textured character ') as d:
            source = Path(d) / 'source mesh.glb'
            out = Path(d) / 'candidate'
            mesh.export(source)
            subprocess.run([os.environ['BLENDER_BIN'], '-b', '--python-exit-code', '1',
                            '-P', str(script), '--', '--input', str(source), '--output-dir', str(out),
                            '--name', 'fixture', '--height', '1.15', '--faces', '500', '250'],
                           check=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
            metrics = json.loads((out / 'fixture_textured_metrics.json').read_text())
            self.assertEqual(len(metrics['outputs']), 3)
            for record in metrics['outputs']:
                scene = trimesh.load(out / record['file'], force='scene')
                actual = next(iter(scene.geometry.values()))
                self.assertEqual(len(actual.faces), record['triangles'])
                if 'budget' in record:
                    self.assertLessEqual(len(actual.faces), record['budget'])
                self.assertAlmostEqual(scene.bounds[0, 1], 0, delta=.015)
                self.assertAlmostEqual(scene.extents[1], 1.15, delta=.025)
                self.assertEqual(actual.visual.kind, 'texture')
                self.assertEqual(actual.visual.material.baseColorTexture.size, (16, 16))
                self.assertGreater(np.ptp(np.asarray(actual.visual.material.baseColorTexture)), 100)
