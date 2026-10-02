"""Check baked colour correspondence on a known two-colour sphere after reduction."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
import numpy as np
import trimesh
from PIL import Image


@unittest.skipUnless(os.environ.get('BLENDER_BIN'), 'Set BLENDER_BIN for real bake')
class LowPolyRebakeTest(unittest.TestCase):
    def test_colour_stays_on_correct_hemisphere(self):
        mesh = trimesh.creation.icosphere(subdivisions=3)
        vertices = mesh.vertices
        uv = np.column_stack((np.arctan2(vertices[:, 2], vertices[:, 0]) / (2*np.pi) + .5,
                              np.arcsin(vertices[:, 1]) / np.pi + .5))
        pixels = np.zeros((256, 256, 3), dtype=np.uint8)
        pixels[:, :128] = [220, 25, 20]
        pixels[:, 128:] = [20, 45, 220]
        mesh.visual = trimesh.visual.texture.TextureVisuals(uv=uv, image=Image.fromarray(pixels))
        script = Path(__file__).resolve().parents[1] / 'rebake_lowpoly.py'
        with tempfile.TemporaryDirectory() as folder:
            folder = Path(folder)
            source = folder / 'source.glb'
            mesh.export(source)
            target = folder/'target.glb'
            trimesh.creation.icosphere(subdivisions=2).export(target)
            for label, target_args in [('decimate', []), ('repaired_target', ['--target-mesh', str(target)])]:
                output = folder/label
                subprocess.run([os.environ['BLENDER_BIN'], '-b', '--python-exit-code', '1',
                                '-P', str(script), '--', '--input', str(source),
                                '--output-dir', str(output), '--faces', '300',
                                '--texture-size', '256', *target_args], check=True, capture_output=True)
                result = trimesh.load(output/'candidate.glb', force='scene', process=False)
                low = trimesh.util.concatenate(result.dump())
                self.assertLessEqual(len(low.faces), 300)
                self.assertAlmostEqual(result.extents[1], 2.0, delta=.001)
                checks = []
                for surface in result.dump():
                    image = np.asarray(surface.visual.material.baseColorTexture)
                    centres = surface.triangles_center
                    coords = surface.visual.uv[surface.faces].mean(axis=1)
                    for point, texcoord in zip(centres, coords):
                        if abs(point[2]) < .3:
                            continue  # Exclude the intentional source seam/boundary.
                        x = min(image.shape[1]-1, max(0, round(float(texcoord[0])*(image.shape[1]-1))))
                        y = min(image.shape[0]-1, max(0, round((1-float(texcoord[1]))*(image.shape[0]-1))))
                        r, _, b = image[y, x, :3].astype(float)
                        checks.append((r > b + 30) if point[2] < 0 else (b > r + 30))
                self.assertGreater(len(checks), 50)
                self.assertGreater(sum(checks)/len(checks), .9, 'Rebake lost surface colour correspondence')



if __name__ == '__main__':
    unittest.main()
