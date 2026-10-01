"""Integration regression: meshes already under budget must not be decimated again."""
import os
import subprocess
import tempfile
import unittest
from pathlib import Path
import trimesh


@unittest.skipUnless(os.environ.get('BLENDER_BIN'), 'Set BLENDER_BIN for Blender integration test')
class BlenderBudgetTest(unittest.TestCase):
    def test_small_mesh_is_preserved(self):
        script = Path(__file__).resolve().parents[1] / 'process_mesh.py'
        with tempfile.TemporaryDirectory(prefix='character budget ') as d:
            source = Path(d) / 'input mesh.glb'
            target = Path(d) / 'output mesh.glb'
            mesh = trimesh.creation.box()
            mesh.export(source)
            subprocess.run([os.environ['BLENDER_BIN'], '-b', '--python-exit-code', '1',
                            '-P', str(script), '--', str(source), str(target), '0.15', '2500'],
                           check=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
            actual = trimesh.load(target, force='mesh')
            self.assertEqual(len(actual.faces), 12)
