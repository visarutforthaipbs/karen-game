import hashlib
import json
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from validate_assets import check, inspect, read_glb
from install_asset import install
from fixtures import cube, write

MANIFEST=json.loads((Path(__file__).resolve().parents[1]/'asset_manifest.json').read_text())


class ValidationTest(unittest.TestCase):
    def test_world_transform_and_degenerate_geometry(self):
        with tempfile.TemporaryDirectory() as tmp:
            path=Path(tmp)/'E3_brush_a.glb'
            cube(path)
            self.assertFalse(check(path,MANIFEST)[1])
            cube(path,scale=10)
            self.assertTrue(any('world-space' in x for x in check(path,MANIFEST)[1]))
            cube(path,indices=[0]*36)
            self.assertTrue(any('zero-area' in x for x in check(path,MANIFEST)[1]))
            cube(path,nonfinite=True)
            self.assertTrue(any('Non-finite' in x for x in check(path,MANIFEST)[1]))

    def test_scene_instances_and_hierarchy_are_counted(self):
        with tempfile.TemporaryDirectory() as tmp:
            path=Path(tmp)/'E3_brush_a.glb'
            cube(path,instances=2)
            self.assertEqual(inspect(path)['tris'],24)
            doc,blob=read_glb(path)
            doc['nodes']=[{'children':[1],'translation':[0,2,0]},{'mesh':0}]
            doc['scenes'][0]['nodes']=[0]
            write(path,doc,blob)
            self.assertTrue(any('grounded' in x for x in check(path,MANIFEST)[1]))
            doc['nodes'][1]['children']=[0];write(path,doc,blob)
            self.assertTrue(any('cyclic' in x for x in check(path,MANIFEST)[1]))

    def test_bounds_indices_material_coverage_and_strict_budget(self):
        with tempfile.TemporaryDirectory() as tmp:
            path=Path(tmp)/'E3_brush_a.glb'
            cube(path,indices=[0,1,99])
            self.assertTrue(check(path,MANIFEST)[1])
            cube(path,missing_color=True)
            self.assertTrue(any('no explicit colour' in x for x in check(path,MANIFEST)[1]))
            cube(path)
            small=json.loads(json.dumps(MANIFEST));small['assets']['E3']['tris']=11
            self.assertTrue(any('strict budget' in x for x in check(path,small)[1]))
            doc,blob=read_glb(path);doc['bufferViews'][0]['byteLength']=2;write(path,doc,blob)
            self.assertTrue(any('buffer view' in x for x in check(path,MANIFEST)[1]))


class InstallationTest(unittest.TestCase):
    def fixture(self, root):
        folder=root/'candidate';folder.mkdir()
        path=folder/'S1_field_hut_a.glb';cube(path,height=3.3)
        run={'asset_id':'S1','variant':'a','profile':'quality','status':'awaiting_visual_review',
             'file':path.name,'candidate_sha256':hashlib.sha256(path.read_bytes()).hexdigest()}
        (folder/'run.json').write_text(json.dumps(run))
        dest=root/'assets/props'/path.name;dest.parent.mkdir(parents=True);dest.write_bytes(b'previous working asset')
        return folder,path,dest

    def test_review_and_tamper_checks_preserve_live_asset(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp);folder,path,dest=self.fixture(root)
            with self.assertRaises(ValueError):install(folder,False,root,lambda _: '')
            path.write_bytes(path.read_bytes()+b'tampered')
            with self.assertRaises(ValueError):install(folder,True,root,lambda _: '')
            self.assertEqual(dest.read_bytes(),b'previous working asset')

    def test_failed_import_rolls_back_then_success_keeps_backup(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp);folder,path,dest=self.fixture(root)
            def fail(_):raise RuntimeError('simulated import failure')
            with self.assertRaises(RuntimeError):install(folder,True,root,fail)
            self.assertEqual(dest.read_bytes(),b'previous working asset')
            install(folder,True,root,lambda _: 'import passed')
            self.assertEqual(dest.read_bytes(),path.read_bytes())
            self.assertTrue(any(p.read_bytes()==b'previous working asset' for p in folder.glob('installation_*/previous.glb')))


if __name__=='__main__':unittest.main()
