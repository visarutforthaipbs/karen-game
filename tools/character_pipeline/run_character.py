#!/usr/bin/env python3
"""Run character candidates on the existing GPU host; production assets are never overwritten.
Example: python3 tools/character_pipeline/run_character.py --image assets/concept_art/tapoh_front_a_pose.jpg --name tapoh --height 1.15 --backend trellis2
"""
import argparse
import hashlib
import json
import math
import re
import shlex
import shutil
import subprocess
import time
import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--image', type=Path, required=True)
    p.add_argument('--name', required=True)
    p.add_argument('--height', type=float, default=1.2)
    p.add_argument('--backend', choices=['triposr-v2', 'trellis2'], default='trellis2')
    p.add_argument('--host', default='gpu')
    p.add_argument('--resolution', choices=['512', '1024'], default='1024', help='TRELLIS profile; 1024 is the tested quality default')
    p.add_argument('--texture-size', type=int, choices=[1024, 2048], default=2048)
    p.add_argument('--faces', type=int, help='Game triangles (default: 12000 textured; 2500 TripoSR)')
    p.add_argument('--steps', type=int, default=12)
    p.add_argument('--remesh-resolution', type=int, choices=[256, 512, 1024],
                   help='Override topology-cleanup grid; does not change neural resolution')
    p.add_argument('--save-material-cache', action='store_true',
                   help='Keep remote mesh/voxel cache for rebaking without inference')
    p.add_argument('--source-only', action='store_true',
                   help='TRELLIS: save the source/cache and defer game preparation to refinement')
    p.add_argument('--seed', type=int, default=1)
    p.add_argument('--noise-seed', type=int, default=18)
    p.add_argument('--output-dir', type=Path)
    args = p.parse_args()
    if args.source_only:
        if args.backend != 'trellis2':
            p.error('--source-only requires TRELLIS')
        args.save_material_cache = True
    if args.faces is None:
        args.faces = 12000 if args.backend == 'trellis2' else 2500
    if not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9_-]*', args.name):
        p.error('name must be letters/digits/underscore/hyphen')
    if not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9_.@-]*', args.host):
        p.error('invalid SSH host')
    if not math.isfinite(args.height) or args.height <= 0 or args.faces < 4 or args.steps < 1 or not args.image.is_file():
        p.error('existing image, positive height and >= 4 faces required')
    suffix = args.image.suffix.lower()
    if suffix not in ['.jpg', '.jpeg', '.png']:
        p.error('image must be PNG or JPEG')
    job = f'{args.name}_{args.backend}_{uuid.uuid4().hex[:10]}'
    out = (args.output_dir or ROOT / 'artifacts' / 'character_candidates' / job).resolve()
    if out.exists() and any(out.iterdir()):
        p.error('output directory must be empty to preserve previous runs')
    out.mkdir(parents=True, exist_ok=True)
    ssh = ['ssh', '-o', 'BatchMode=yes', '-o', 'ConnectTimeout=15', args.host]
    def remote(argv, **kwargs):
        return subprocess.run(ssh + [shlex.join([str(a) for a in argv])], check=True, **kwargs)
    home = remote(['pwd'], capture_output=True, text=True).stdout.strip()
    remote_dir = f'{home}/character_candidates/{job}'
    remote_out = remote_dir + '/output'
    health = remote(['nvidia-smi', '--query-gpu=name,memory.total,memory.free,utilization.gpu',
                     '--format=csv,noheader,nounits'], capture_output=True, text=True).stdout.strip()
    if not health or any(marker in health.upper() for marker in ('N/A', 'ERR!')):
        raise RuntimeError(f'GPU is not healthy; recover the device before inference: {health}')
    free = health.splitlines()[0].split(',')[2].strip()
    needed = (20000 if args.resolution == '1024' else 12000) if args.backend == 'trellis2' else 6000
    if int(free) < needed:
        raise RuntimeError(f'Need {needed} MiB free VRAM; currently {free}')
    remote(['mkdir', '-p', remote_out])
    image = remote_dir + '/input' + suffix
    subprocess.run(['scp', '-q', str(args.image.resolve()), f'{args.host}:{image}'], check=True)
    blender = f'{home}/apps/blender-4.5.14-linux-x64/blender'
    python = f'{home}/aienv/bin/python3'
    started = time.perf_counter()
    manifest = {'job': job, 'backend': args.backend, 'input': str(args.image.resolve()),
                'input_sha256': hashlib.sha256(args.image.read_bytes()).hexdigest(),
                'height': args.height, 'seed': args.seed, 'noise_seed': args.noise_seed,
                'source_only': args.source_only,
                'resolution': args.resolution, 'texture_size': args.texture_size,
                'faces': args.faces, 'steps': args.steps, 'remesh_resolution': args.remesh_resolution,
                'material_cache': remote_dir + '/material_cache' if args.save_material_cache else None,
                'remote_dir': remote_dir, 'status': 'running', 'free_vram_mib_at_start': int(free), 'gpu_health_at_start': health}
    (out / 'run.json').write_text(json.dumps(manifest, indent=2))
    print(f'Running {job}; log: {out / "run.log"}', flush=True)
    scripts = ([Path(__file__).with_name('prepare_textured_character.py')] if args.backend == 'trellis2' else
               [ROOT / 'tools/character_pipeline_v2' / f for f in ['generate_character_v2.py', 'process_mesh.py']])
    snapshot = out / 'pipeline_source'
    snapshot.mkdir()
    scripts = [Path(shutil.copy2(s, snapshot / s.name)) for s in scripts]
    shutil.copy2(__file__, snapshot / Path(__file__).name)
    manifest['script_sha256'] = {s.name: hashlib.sha256(s.read_bytes()).hexdigest() for s in snapshot.iterdir()}
    try:
        with (out / 'run.log').open('w') as log:
            if args.backend == 'trellis2':
                runtime = f'{home}/tools/trellis2.c'
                model_root = f'{home}/tools/TRELLIS.2'
                manifest['native_revision'] = remote(['git', '-C', runtime, 'rev-parse', 'HEAD'],
                    capture_output=True, text=True).stdout.strip()
                manifest['native_binary_sha256'] = remote(['sha256sum',
                    runtime + '/build-cuda/trellis2-image-to-gltf', runtime + '/build-cuda/vkmesh',
                    runtime + '/build-cuda/libtrellis2_c.so'], capture_output=True, text=True).stdout.strip()
                raw = remote_out + f'/{args.name}_raw.glb'
                command = ['env', 'TRELLIS_VKMESH_HOST_MEMORY=1',
                           f'{runtime}/build-cuda/trellis2-image-to-gltf',
                           '--model', f'{model_root}/TRELLIS.2-4B',
                           '--dino', f'{model_root}/dinov3-vitl16-pretrain-lvd1689m',
                           '--image', image, '--pipeline', args.resolution,
                           '--texture-size', str(args.texture_size), '--steps', str(args.steps),
                           '--prepared-image-output', remote_out + '/prepared_input.png', '--seed', str(args.seed),
                           '--noise-seed', str(args.noise_seed), '--no-model-cache', '--mesh-postprocess-simplify',
                           '--mesh-decimation-target', '100000',
                           '--vkmesh-gpu-workspace-budget-mib', '2048', '--output', raw]
                if args.remesh_resolution:
                    command.extend(['--mesh-remesh-resolution', str(args.remesh_resolution)])
                if args.save_material_cache:
                    remote(['mkdir', '-p', manifest['material_cache']])
                    command.insert(2, 'TRELLIS_MATERIAL_DUMP_DIR=' + manifest['material_cache'])
                remote(command, stdout=log, stderr=subprocess.STDOUT)
                if not args.source_only:
                    subprocess.run(['scp', '-q', str(scripts[0]), f'{args.host}:{remote_dir}/'], check=True)
                    remote([blender, '-b', '--python-exit-code', '1', '-P', remote_dir + '/' + scripts[0].name,
                            '--', '--input', raw, '--output-dir', remote_out, '--name', args.name,
                            '--height', str(args.height), '--faces', str(args.faces)],
                           stdout=log, stderr=subprocess.STDOUT)
            else:
                subprocess.run(['scp', '-q', *map(str, scripts), f'{args.host}:{remote_dir}/'], check=True)
                remote([python, remote_dir + '/generate_character_v2.py', '--image', image,
                        '--name', args.name, '--height', str(args.height), '--faces', str(args.faces),
                        '--blender', blender, '--output-dir', remote_out], stdout=log, stderr=subprocess.STDOUT)
        subprocess.run(['scp', '-q', '-r', f'{args.host}:{remote_out}/.', str(out)], check=True)
        manifest['status'] = 'complete'
    except Exception as exc:
        manifest['status'] = 'failed'
        manifest['error'] = str(exc)
        # Keep partial masters and diagnostic images even if a later LOD fails.
        result = subprocess.run(['scp', '-q', '-r', f'{args.host}:{remote_out}/.', str(out)])
        manifest['partial_outputs_downloaded'] = result.returncode == 0
        raise
    finally:
        manifest['elapsed_seconds'] = round(time.perf_counter() - started, 3)
        (out / 'run.json').write_text(json.dumps(manifest, indent=2))
    print(f'Candidate outputs: {out}', flush=True)


if __name__ == '__main__':
    main()
