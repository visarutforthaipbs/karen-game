"""Cache identity and GPU preflight must fail before launching inference."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import subprocess
import sys
from types import SimpleNamespace

SCRIPT = Path(__file__).resolve().parents[1] / 'run_refined_character.py'
spec = importlib.util.spec_from_file_location('refined_runner', SCRIPT)
runner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runner)


class RefinedRunnerTest(unittest.TestCase):
    def test_recipe_preserves_actual_cache_settings(self):
        args = SimpleNamespace(generation_steps=12, seed=1, noise_seed=18, texture_steps=24, texture_seed=42, cleanup_grid=512, closing_iterations=2)
        self.assertEqual(runner.recipe_for(args), runner.RECIPE)
        recipe = runner.recipe_for(args, {'steps': 24, 'seed': 2, 'noise_seed': 29})
        self.assertEqual((recipe['generation_steps'], recipe['generation_seed'],
                          recipe['generation_noise_seed']), (24, 2, 29))
        self.assertEqual(runner.RECIPE['generation_seed'], 1)
        args.texture_seed = 8
        self.assertEqual(runner.recipe_for(args, {'steps': 24, 'seed': 2, 'noise_seed': 29})['texture_seed'], 8)
        self.assertEqual(runner.RECIPE['texture_seed'], 42)
        with self.assertRaises(ValueError):
            runner.recipe_for(args, {'steps': 24})

    def test_cache_identity_and_completeness(self):
        with tempfile.TemporaryDirectory() as folder:
            image, manifest = Path(folder) / 'image.png', Path(folder) / 'run.json'
            image.write_bytes(b'reference identity fixture')
            valid = {'backend': 'trellis2', 'resolution': '1024', 'status': 'complete',
                     'input_sha256': runner.digest(image), 'remote_dir': '/home/test/job',
                     'material_cache': '/home/test/job/material_cache'}
            manifest.write_text(json.dumps(valid))
            self.assertEqual(runner.read_source(manifest, image), valid)
            for changes in ({'input_sha256': 'wrong'}, {'status': 'failed'}, {'resolution': '512'},
                            {'material_cache': '/home/test/other/material_cache'},
                            {'material_cache': '/home/test/job/../material_cache'}):
                with self.subTest(changes=changes):
                    manifest.write_text(json.dumps({**valid, **changes}))
                    with self.assertRaises(ValueError):
                        runner.read_source(manifest, image)

    def test_gpu_reset_or_other_workload_blocks_inference(self):
        runner.require_gpu_health('NVIDIA RTX 3090, 24576, 24125, 0')
        for report in ('', 'NVIDIA RTX 3090, 24576, 14483, 0',
                       'NVIDIA RTX 3090, 24576, N/A, ERR!'):
            with self.subTest(report=report), self.assertRaises(RuntimeError):
                runner.require_gpu_health(report)

    def test_source_only_keeps_cache_without_preparing_damaged_mesh(self):
        source_spec = importlib.util.spec_from_file_location('source_runner', SCRIPT.with_name('run_character.py'))
        source_runner = importlib.util.module_from_spec(source_spec)
        source_spec.loader.exec_module(source_runner)
        calls = []

        def fake_run(command, **kwargs):
            calls.append(command)
            remote_command = command[-1]
            stdout = ''
            if remote_command == 'pwd':
                stdout = '/home/fixture\n'
            elif 'nvidia-smi' in remote_command:
                stdout = 'NVIDIA RTX 3090, 24576, 24125, 0\n'
            return subprocess.CompletedProcess(command, 0, stdout=stdout)

        with tempfile.TemporaryDirectory() as folder:
            image, out = Path(folder) / 'input.png', Path(folder) / 'result'
            image.write_bytes(b'fixture')
            argv = ['run_character.py', '--image', str(image), '--name', 'fixture',
                    '--source-only', '--output-dir', str(out)]
            with patch.object(sys, 'argv', argv), patch.object(source_runner.subprocess, 'run', side_effect=fake_run):
                source_runner.main()
            data = json.loads((out / 'run.json').read_text())
            self.assertEqual(data['status'], 'complete')
            self.assertTrue(data['material_cache'])
            self.assertTrue(any('TRELLIS_MATERIAL_DUMP_DIR=' in c[-1] for c in calls))
            self.assertFalse(any('--python-exit-code' in c[-1] for c in calls))


if __name__ == '__main__':
    unittest.main()
