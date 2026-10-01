#!/usr/bin/env python3
"""One-command candidate build using the successful Kha-nae surface/texture recipe."""
import argparse
import hashlib
import json
import math
from pathlib import Path
import re
import shlex
import shutil
import subprocess
import sys
import time
import uuid

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
RECIPE = {
    'version': 'khanae-refined-v1', 'generation_resolution': 1024,
    'generation_steps': 12, 'generation_seed': 1, 'generation_noise_seed': 18,
    'cleanup_grid': 512, 'closing_iterations': 2, 'fill_holes': True,
    'smoothing_factor': 0.35, 'smoothing_iterations': 2,
    'intermediate_triangles': 150000, 'texture_resolution': 1024,
    'texture_size': 2048, 'texture_steps': 24, 'texture_seed': 42,
}


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def read_source(path, image):
    """Reject accidental reuse of another character's material cache."""
    data = json.loads(path.read_text())
    if (data.get('backend') != 'trellis2' or str(data.get('resolution')) != '1024'
            or data.get('status') != 'complete' or not data.get('material_cache')):
        raise ValueError('Source must be a completed 1024 TRELLIS run with a material cache')
    if data.get('input_sha256') != digest(image):
        raise ValueError('Reference image does not match the source run hash')
    for key in ('remote_dir', 'material_cache'):
        if not re.fullmatch(r'/[A-Za-z0-9_./-]+', data[key]) or '..' in Path(data[key]).parts:
            raise ValueError('Invalid remote cache path')
    if Path(data['material_cache']).parent != Path(data['remote_dir']):
        raise ValueError('Cache must belong to the source job')
    return data


def require_gpu_health(health):
    if not health or any(marker in health.upper() for marker in ('N/A', 'ERR!')):
        raise RuntimeError(f'GPU needs recovery: {health}')
    fields = health.splitlines()[0].split(',')
    if len(fields) != 4 or int(fields[2].strip()) < 20000:
        raise RuntimeError(f'Refined recipe needs 20,000 MiB free VRAM: {health}')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--image', type=Path, required=True)
    parser.add_argument('--name', required=True)
    parser.add_argument('--height', type=float, default=1.2)
    parser.add_argument('--faces', type=int, default=40000)
    parser.add_argument('--host', default='gpu')
    parser.add_argument('--from-run', type=Path, help='Reuse a completed run.json and its remote cache')
    parser.add_argument('--output-dir', type=Path)
    parser.add_argument('--skip-preview', action='store_true', help='For hosts without a Godot display')
    args = parser.parse_args()
    if not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9_-]*', args.name):
        parser.error('Invalid character name')
    if not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9_.@-]*', args.host):
        parser.error('Invalid SSH host')
    if (not args.image.is_file() or args.image.suffix.lower() not in ('.png', '.jpg', '.jpeg')
            or not math.isfinite(args.height) or args.height <= 0 or args.faces < 4):
        parser.error('PNG/JPEG reference, positive height and at least 4 faces required')
    source = read_source(args.from_run, args.image) if args.from_run else None
    if not args.skip_preview and not shutil.which('godot'):
        parser.error('Godot is needed for preview; use --skip-preview on a headless host')
    job = f'{args.name}_refined_{uuid.uuid4().hex[:10]}'
    out = (args.output_dir or ROOT / 'artifacts/character_candidates' / job).resolve()
    if out.exists() and (not out.is_dir() or any(out.iterdir())):
        parser.error('Output directory must be empty; previous results are preserved')
    out.mkdir(parents=True, exist_ok=True)
    manifest = {'job': job, 'status': 'running', 'recipe': RECIPE,
                'input': str(args.image.resolve()), 'input_sha256': digest(args.image),
                'host': args.host, 'height': args.height, 'faces': args.faces,
                'visual_review': 'required', 'installed': False, 'rigged': False, 'stages': []}
    started = time.monotonic()
    remote_out = None
    ssh = ['ssh', '-o', 'BatchMode=yes', '-o', 'ConnectTimeout=15', args.host]

    def save():
        (out / 'run.json').write_text(json.dumps(manifest, indent=2) + '\n')

    def remote(command, **kwargs):
        return subprocess.run(ssh + [shlex.join(list(map(str, command)))], check=True, **kwargs)

    def preflight():
        health = remote(['nvidia-smi', '--query-gpu=name,memory.total,memory.free,utilization.gpu',
                         '--format=csv,noheader,nounits'], capture_output=True, text=True).stdout.strip()
        manifest.setdefault('gpu_checks', []).append(health)
        require_gpu_health(health)

    def stage(name, action):
        record = {'name': name, 'status': 'running'}
        manifest['stages'].append(record)
        save()
        print(f'[{job}] {name}', flush=True)
        begin = time.monotonic()
        try:
            result = action()
            record['status'] = 'complete'
            return result
        except Exception as exc:
            record.update(status='failed', error=str(exc))
            raise
        finally:
            record['elapsed_seconds'] = round(time.monotonic() - begin, 3)
            save()

    save()
    try:
        snapshot = out / 'pipeline_source'
        snapshot.mkdir()
        files = ['run_refined_character.py', 'run_character.py', 'rebuild_cached_surface.py',
                 'decimate_cached_surface.py', 'prepare_textured_character.py', 'validate_refined_character.py']
        for name in files:
            shutil.copy2(HERE / name, snapshot / name)
        shutil.copy2(ROOT / 'tools/character_pipeline_v2/render_benchmark.gd', snapshot)
        manifest['script_sha256'] = {p.name: digest(p) for p in snapshot.iterdir()}
        shutil.copy2(args.image, out / ('reference' + args.image.suffix.lower()))
        stage('gpu_preflight', preflight)
        with (out / 'run.log').open('w') as log:
            if source is None:
                stage('generate_source', lambda: subprocess.run([
                    sys.executable, str(HERE / 'run_character.py'), '--image', str(args.image.resolve()),
                    '--name', args.name, '--height', str(args.height), '--faces', str(args.faces),
                    '--host', args.host, '--backend', 'trellis2', '--resolution', '1024',
                    '--steps', '12', '--seed', '1', '--noise-seed', '18', '--texture-size', '2048',
                    '--remesh-resolution', '512', '--save-material-cache', '--source-only',
                    '--output-dir', str(out / 'source')], check=True, stdout=log, stderr=subprocess.STDOUT))
                args.from_run = out / 'source/run.json'
                source = read_source(args.from_run, args.image)
            manifest['source_run'] = str(args.from_run.resolve())
            manifest['source_job'] = source['job']
            shutil.copy2(args.from_run, out / 'source_run.json')
            home = remote(['pwd'], capture_output=True, text=True).stdout.strip()
            remote_dir = f'{home}/character_candidates/{job}'
            remote_out = remote_dir + '/output'
            cache = source['material_cache']
            prepared_image = source['remote_dir'] + '/output/prepared_input.png'
            manifest.update(remote_dir=remote_dir, material_cache=cache)
            runtime = f'{home}/tools/trellis2.c/build-cuda'
            model = f'{home}/tools/TRELLIS.2'
            blender = f'{home}/apps/blender-4.5.14-linux-x64/blender'
            python = f'{home}/aienv/bin/python3'
            binaries = [runtime + '/' + n for n in ('trellis-rebake-gltf', 'trellis2-texture-mesh',
                                                      'vkmesh', 'libtrellis2_c.so')]
            manifest['native_binary_sha256'] = remote(['sha256sum', *binaries], capture_output=True, text=True).stdout.strip()
            manifest['native_revision'] = remote(['git', '-C', str(Path(runtime).parent), 'rev-parse', 'HEAD'],
                                                  capture_output=True, text=True).stdout.strip()
            # Check the remote input too: a matching local manifest alone is insufficient.
            remote_input = source['remote_dir'] + '/input' + Path(source['input']).suffix.lower()
            remote_hash = remote(['sha256sum', remote_input], capture_output=True, text=True).stdout.split()[0]
            if remote_hash != manifest['input_sha256']:
                raise ValueError('Remote source input has changed since the generation run')
            manifest['cache_sha256'] = remote(['sha256sum', cache + '/pbr_voxels.bin', cache + '/raw.meshbin',
                                               prepared_image], capture_output=True, text=True).stdout.strip()
            remote(['mkdir', remote_dir])
            remote(['mkdir', remote_out])
            subprocess.run(['scp', '-q', *map(str, (snapshot / n for n in files)),
                            f'{args.host}:{remote_dir}/'], check=True)

            def execute(name, command):
                return stage(name, lambda: remote(command, stdout=log, stderr=subprocess.STDOUT))

            def prepare(name, input_path, output_path):
                execute(name, [blender, '-b', '--python-exit-code', '1', '-P',
                              remote_dir + '/prepare_textured_character.py', '--', '--input', input_path,
                              '--output-dir', output_path, '--name', args.name,
                              '--height', args.height, '--faces', args.faces])

            execute('rebuild_surface', [python, remote_dir + '/rebuild_cached_surface.py',
                                       cache + '/pbr_voxels.bin', remote_out + '/closed.meshbin'])
            execute('smooth_surface', [blender, '-b', '--python-exit-code', '1', '-P',
                                      remote_dir + '/decimate_cached_surface.py', '--',
                                      remote_out + '/closed.meshbin', remote_out + '/reduced.meshbin'])
            execute('rebake_cached_material', ['env', 'TRELLIS_VKMESH_HOST_MEMORY=1',
                    runtime + '/trellis-rebake-gltf', '--mesh', remote_out + '/reduced.meshbin',
                    '--voxels', cache + '/pbr_voxels.bin', '--sample', cache + '/raw.meshbin',
                    '--texture-size', '2048', '--gltf', remote_out + '/rebaked.glb'])
            prepare('prepare_game_surface', remote_out + '/rebaked.glb', remote_out + '/surface')
            stage('texture_gpu_preflight', preflight)
            execute('generate_fresh_texture', ['env', 'TRELLIS_VKMESH_HOST_MEMORY=1',
                    runtime + '/trellis2-texture-mesh', '--model', model + '/TRELLIS.2-4B',
                    '--dino', model + '/dinov3-vitl16-pretrain-lvd1689m',
                    '--input', remote_out + f'/surface/{args.name}_{args.faces}tris.glb',
                    '--image', prepared_image, '--image-prepared', '--resolution', '1024',
                    '--texture-size', '2048', '--steps', '24', '--seed', '42',
                    '--shape-latent-output', remote_out + '/shape.slat',
                    '--output', remote_out + '/retextured.glb'])
            prepare('restore_game_scale', remote_out + '/retextured.glb', remote_out + '/candidate')
            candidate = remote_out + f'/candidate/{args.name}_{args.faces}tris.glb'
            execute('validate_game_candidate', [python, remote_dir + '/validate_refined_character.py',
                    candidate, '--height', args.height, '--faces', args.faces, '--texture-size', '2048',
                    '--output', remote_out + '/candidate/validation.json'])
        stage('download', lambda: subprocess.run(['scp', '-q', '-r', f'{args.host}:{remote_out}/.',
                                                  str(out)], check=True))
        candidate = out / f'candidate/{args.name}_{args.faces}tris.glb'
        manifest['candidate'] = str(candidate)
        manifest['candidate_sha256'] = digest(candidate)
        manifest['technical_validation'] = json.loads((out / 'candidate/validation.json').read_text())
        rows = [{'label': 'Rebuilt / cached texture', 'path': str(out / f'surface/{args.name}_{args.faces}tris.glb'),
                 'vertex_material': False},
                {'label': 'Refined / fresh texture', 'path': str(candidate), 'vertex_material': False}]
        (out / 'preview_manifest.json').write_text(json.dumps(rows, indent=2))
        if not args.skip_preview:
            with (out / 'preview.log').open('w') as log:
                stage('render_preview', lambda: subprocess.run([
                    'godot', '--path', str(ROOT), '--rendering-method', 'gl_compatibility',
                    '--script', str(snapshot / 'render_benchmark.gd'), '--',
                    str(out / 'preview_manifest.json'), str(out / 'preview.png')],
                    check=True, timeout=180, stdout=log, stderr=subprocess.STDOUT))
            if not (out / 'preview.png').is_file():
                raise RuntimeError('Godot did not produce a preview')
        manifest['preview_status'] = 'skipped' if args.skip_preview else 'ready'
        manifest['status'] = 'awaiting_visual_review'
        print(f'Candidate ready for visual review: {candidate}\nReview folder: {out}', flush=True)
    except Exception as exc:
        manifest.update(status='failed', error=str(exc))
        if remote_out:
            partial = out / 'partial'
            partial.mkdir(exist_ok=True)
            result = subprocess.run(['scp', '-q', '-r', f'{args.host}:{remote_out}/.', str(partial)])
            manifest['partial_outputs_downloaded'] = result.returncode == 0
        raise
    finally:
        manifest['elapsed_seconds'] = round(time.monotonic() - started, 3)
        save()


if __name__ == '__main__':
    main()
