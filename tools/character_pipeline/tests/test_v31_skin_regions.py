"""Regression points taken from rejected v3.1 deformation reports."""
import ast
import json
from pathlib import Path
import unittest
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
tree = ast.parse((ROOT / 'rig_character.py').read_text())
functions = [node for node in tree.body if isinstance(node, ast.FunctionDef) and node.name in ('smooth', 'v31_weights')]
scope = {'np': np}
exec(compile(ast.Module(body=functions, type_ignores=[]), str(ROOT / 'rig_character.py'), 'exec'), scope)

class RegionRegression(unittest.TestCase):
    def weights(self, name, point, cloth=False):
        suffix = 'v11' if name == 'ranger' else 'v31'
        profile = json.loads((ROOT / f'rig_profiles/{name}_{suffix}.json').read_text())
        return scope['v31_weights'](*point, profile, cloth)

    def test_hands_do_not_follow_hips_or_thighs(self):
        points = {'khanae':(-.2358,.3894,.1038), 'tapoh':(-.2244,.3807,.1577),
                  'munaw':(-.2075,.4029,.0836), 'maelu':(-.2259,.4381,.0827)}
        for name, point in points.items():
            with self.subTest(name=name):
                w = self.weights(name,point)
                self.assertGreater(sum(v for k,v in w.items() if k.startswith(('Hand.','Forearm.','UpperArm.'))), .98)

    def test_trousers_do_not_follow_hands(self):
        for name in ['khanae','tapoh']:
            w = self.weights(name,(.185,.265,.034))
            self.assertLess(sum(v for k,v in w.items() if k.startswith(('Hand.','Forearm.','UpperArm.'))), .001)

    def test_ranger_lowered_hands_and_shoulder_are_separate(self):
        for point in [( .2966,.319,.05),(-.30,.445,-.11),(.24,.50,-.10)]:
            w = self.weights('ranger',point)
            self.assertGreater(sum(v for k,v in w.items() if k.startswith(('Hand.','Forearm.','UpperArm.'))), .98)
        w = self.weights('ranger',(.21,.38,-.1))
        self.assertFalse(any(k.startswith(('Hand.','Forearm.','UpperArm.')) for k in w))
        w = self.weights('ranger',(-.16,.64,-.19))
        self.assertNotIn('Head',w)  # Ranger has no scarf or hair tail at the shoulders.

    def test_dress_hem_never_splits_onto_legs(self):
        for x in [-.17,0,.17]:
            w = self.weights('munaw',(x,.215,.10),True)
            self.assertFalse(any(k.startswith(('Thigh.','Shin.','Foot.','Hand.')) for k in w))
            self.assertAlmostEqual(sum(w.values()),1)

    def test_head_and_headwear_are_rigid(self):
        for name in ['khanae','tapoh','munaw','maelu']:
            self.assertEqual(self.weights(name,(.15,1.0,-.1)), {'Head':1})

if __name__ == '__main__': unittest.main()
