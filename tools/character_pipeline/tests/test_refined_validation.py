"""Catch the scale/origin reset observed after texture-only export."""
import importlib.util
from pathlib import Path
import tempfile
import unittest

AVAILABLE = all(importlib.util.find_spec(name) for name in ('numpy', 'trimesh', 'PIL'))


@unittest.skipUnless(AVAILABLE, 'requires GPU geometry Python dependencies')
class RefinedValidationTest(unittest.TestCase):
    def test_valid_mesh_then_wrong_scale_origin_and_missing_texture(self):
        import numpy as np
        import trimesh
        from PIL import Image
        path = Path(__file__).resolve().parents[1] / 'validate_refined_character.py'
        spec = importlib.util.spec_from_file_location('refined_validation', path)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        mesh = trimesh.creation.box(extents=[0.5, 1.2, 0.3])
        mesh.apply_translation([0, 0.6, 0])
        mesh.visual = trimesh.visual.texture.TextureVisuals(
            uv=np.zeros((len(mesh.vertices), 2)), image=Image.new('RGB', (16, 16), 'red'))
        with tempfile.TemporaryDirectory() as folder:
            glb = Path(folder) / 'candidate.glb'
            mesh.export(glb)
            self.assertTrue(module.validate(glb, 1.2, 12, 16)['passed'])
            self.assertFalse(module.validate(glb, 1.2, 10, 16)['passed'])
            self.assertFalse(module.validate(glb, 1.2, 12, 32)['passed'])
            mesh.apply_translation([0, 0.3, 0])
            mesh.export(glb)
            self.assertFalse(module.validate(glb, 1.2, 12, 16)['passed'])
            mesh.apply_scale(2)
            mesh.export(glb)
            self.assertFalse(module.validate(glb, 1.2, 12, 16)['passed'])
            trimesh.creation.box().export(glb)
            with self.assertRaises(ValueError):
                module.validate(glb, 1, 12, 16)


if __name__ == '__main__':
    unittest.main()
