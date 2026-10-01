"""Run with the GPU Python environment (NumPy, SciPy, scikit-image, trimesh)."""
import importlib.util
from pathlib import Path
import struct
import subprocess
import sys
import tempfile
import unittest

AVAILABLE = all(importlib.util.find_spec(name) for name in ('numpy', 'scipy', 'skimage', 'trimesh'))
SCRIPT = Path(__file__).resolve().parents[1] / 'rebuild_cached_surface.py'

@unittest.skipUnless(AVAILABLE, 'requires the GPU geometry Python dependencies')
class CachedSurfaceTest(unittest.TestCase):
    def test_open_voxel_shell_recovers_closed_finite_surface(self):
        import numpy as np
        import trimesh
        with tempfile.TemporaryDirectory() as tmp:
            src, dst = Path(tmp)/'pbr.bin', Path(tmp)/'surface.meshbin'
            # Cube shell with one missing surface voxel: recovery must close the hole.
            xyz = [(x,y,z) for x in range(100,116) for y in range(100,116) for z in range(100,116)
                   if min(x,y,z)==100 or max(x,y,z)==115]
            xyz.remove((100,107,107))
            coords = np.array([(0,*v) for v in xyz],dtype='<i4')
            src.write_bytes(struct.pack('<8sqii',b'TRLPBR1\0',len(coords),6,1024)+coords.tobytes()
                            +np.zeros((len(coords),6),dtype='<f4').tobytes())
            subprocess.run([sys.executable,str(SCRIPT),str(src),str(dst)],check=True,capture_output=True)
            data=dst.read_bytes(); magic,nv,nf,flags,_=struct.unpack_from('<8sQQII',data)
            vertices=np.frombuffer(data,dtype='<f4',count=nv*3,offset=32).reshape(-1,3)
            faces=np.frombuffer(data,dtype='<i4',count=nf*3,offset=32+nv*12).reshape(-1,3)
            mesh=trimesh.Trimesh(vertices=vertices,faces=faces,process=False)
            self.assertEqual(magic,b'TRLMESH1')
            self.assertTrue(np.isfinite(vertices).all())
            self.assertTrue(mesh.is_watertight)
            self.assertTrue((mesh.area_faces>0).all())
            np.testing.assert_allclose(mesh.bounds.mean(axis=0),np.full(3,108/1024-0.5),atol=1/1024)
            # A retry must preserve the already generated candidate.
            again=subprocess.run([sys.executable,str(SCRIPT),str(src),str(dst)],capture_output=True)
            self.assertNotEqual(again.returncode,0)
            self.assertEqual(dst.read_bytes(),data)

if __name__=='__main__':
    unittest.main()
