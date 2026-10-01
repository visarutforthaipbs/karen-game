"""Regression tests for colour clipping, orientation and exported appearance.
Run with the pipeline Python environment: python -m unittest discover -s tests -v
"""
import sys
import tempfile
import unittest
from pathlib import Path
import numpy as np
import trimesh
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from generate_character_v2 import color_grade_vertices, orient_and_ground, mesh_metrics


class PipelineTests(unittest.TestCase):
    def test_colour_survives_grade_and_glb_roundtrip(self):
        mesh = trimesh.creation.icosphere(subdivisions=1)
        rgb = np.array([[20, 35, 95, 255], [165, 45, 30, 255], [180, 140, 65, 255]], dtype=np.uint8)
        mesh.visual.vertex_colors = rgb[np.arange(len(mesh.vertices)) % 3]
        out = color_grade_vertices(mesh)
        with tempfile.TemporaryDirectory() as d:
            path = Path(d) / 'colours.glb'
            out.export(path)
            loaded = trimesh.load(path, force='mesh')
        c = loaded.visual.vertex_colors
        self.assertEqual(c.dtype, np.uint8)
        self.assertLess(mesh_metrics(loaded)['white_fraction'], 0.01)
        self.assertGreater(np.std(c[:, :3]), 25)
        # Indigo remains blue-dominant rather than turning into white.
        blue = c[np.arange(len(c)) % 3 == 0]
        self.assertTrue(np.all(blue[:, 2] > blue[:, 0]))

    def test_ground_height_center_and_colour(self):
        mesh = trimesh.creation.box(extents=[4, 2, 1])
        mesh.apply_translation([7, -3, 8])
        mesh.visual.vertex_colors = np.tile(np.array([20, 40, 60, 255], dtype=np.uint8), (len(mesh.vertices), 1))
        out = orient_and_ground(mesh, 1.15)
        self.assertAlmostEqual(out.extents[1], 1.15)
        self.assertAlmostEqual(out.bounds[0, 1], 0)
        np.testing.assert_allclose(out.bounds[:, [0, 2]].mean(axis=0), [0, 0], atol=1e-8)
        np.testing.assert_array_equal(out.visual.vertex_colors[0], [20, 40, 60, 255])

    def test_white_output_is_detectable(self):
        mesh = trimesh.creation.box()
        mesh.visual.vertex_colors = np.full((len(mesh.vertices), 4), 255, dtype=np.uint8)
        metrics = mesh_metrics(mesh)
        self.assertEqual(metrics['white_fraction'], 1)
        self.assertEqual(metrics['unique_rgb'], 1)


if __name__ == '__main__':
    unittest.main()
