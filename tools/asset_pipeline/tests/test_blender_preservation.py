"""Real headless Blender regression: retain textures and small disconnected parts."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
import sys
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from validate_assets import read_glb, inspect, accessor


@unittest.skipUnless(os.environ.get('BLENDER_BIN'),'Set BLENDER_BIN for real export checks')
class BlenderPreservationTest(unittest.TestCase):
    def test_texture_and_small_parts_survive_cleanup(self):
        with tempfile.TemporaryDirectory() as folder:
            folder=Path(folder)
            script=folder/'fixture.py'
            script.write_text('''import bpy, math
from pathlib import Path
p=Path(__file__).parent
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.mesh.primitive_uv_sphere_add(segments=32,ring_count=16)
body=bpy.context.object
for poly in body.data.polygons: poly.use_smooth=True
image=bpy.data.images.new('Pattern',width=16,height=16)
image.pixels=[v for y in range(16) for x in range(16) for v in ((1,0,0,1) if x<8 else (0,0,1,1))]
mat=bpy.data.materials.new('Textured');mat.use_nodes=True
node=mat.node_tree.nodes.new('ShaderNodeTexImage');node.image=image
mat.node_tree.links.new(node.outputs['Color'],mat.node_tree.nodes['Principled BSDF'].inputs['Base Color'])
body.data.materials.append(mat)
bpy.ops.mesh.primitive_cube_add(size=.1,location=(1.5,0,0))
bpy.context.object.data.materials.append(mat)
bpy.ops.export_scene.gltf(filepath=str(p/'input.glb'),export_format='GLB')
''')
            subprocess.run([os.environ['BLENDER_BIN'],'-b','--python-exit-code','1','-P',str(script)],check=True,capture_output=True)
            output=folder/'output.glb'
            subprocess.run([os.environ['BLENDER_BIN'],'-b','--python-exit-code','1','-P',
                str(Path(__file__).resolve().parents[1]/'gpu/blender_cleanup.py'),'--','--in',str(folder/'input.glb'),
                '--out',str(output),'--tris','2000','--fit','height','--meters','2',
                '--material-mode','preserve'],check=True,capture_output=True)
            info=inspect(output)
            self.assertGreater(info['max'][0]-info['min'][0],2.5,'Small detached cube was discarded')
            self.assertEqual(info['zero_area'],0)
            self.assertGreater(info['textured_surfaces'],0)
            source,_=read_glb(folder/'input.glb');result,blob=read_glb(output)
            self.assertEqual(len(source['images']),len(result['images']))
            self.assertTrue(all('TEXCOORD_0' in p['attributes'] for m in result['meshes'] for p in m['primitives']))
            for mesh in result['meshes']:
                for primitive in mesh['primitives']:
                    normals=accessor(result,blob,primitive['attributes']['NORMAL'])
                    indices=[row[0] for row in accessor(result,blob,primitive['indices'])]
                    for i in range(0,len(indices),3):
                        face=[normals[j] for j in indices[i:i+3]]
                        self.assertTrue(all(abs(face[0][k]-n[k])<1e-5 for n in face[1:] for k in range(3)),
                                        'Textured game mesh retained smooth normals')
            # Vertex mode must reject a texture-only mesh, never silently turn it grey.
            refused=subprocess.run([os.environ['BLENDER_BIN'],'-b','--python-exit-code','1','-P',
                str(Path(__file__).resolve().parents[1]/'gpu/blender_cleanup.py'),'--','--in',str(folder/'input.glb'),
                '--out',str(folder/'bad.glb'),'--tris','2000','--fit','height','--meters','2',
                '--material-mode','vertex'],capture_output=True)
            self.assertNotEqual(refused.returncode,0)
            self.assertFalse((folder/'bad.glb').exists())


if __name__=='__main__':unittest.main()
