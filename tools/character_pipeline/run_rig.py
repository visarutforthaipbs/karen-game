#!/usr/bin/env python3
"""Build a calibrated rig using headless Blender on the existing GPU host (CPU work)."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shlex
import shutil
import subprocess
import time
import uuid

HERE = Path(__file__).resolve().parent


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--input', type=Path, required=True)
    p.add_argument('--profile', type=Path, default=HERE / 'rig_profiles/khanae.json')
    p.add_argument('--host', default='gpu')
    p.add_argument('--output-dir', type=Path)
    args = p.parse_args()
    if not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9_.@-]*', args.host):
        p.error('Invalid SSH host')
    profile = json.loads(args.profile.read_text())
    if hashlib.sha256(args.input.read_bytes()).hexdigest() not in profile['source_sha256']:
        p.error('Input does not match calibrated profile; review landmarks and skinning first')
    job = 'character_rig_' + uuid.uuid4().hex[:10]
    out = (args.output_dir or HERE.parents[1] / 'artifacts/character_candidates' / job).resolve()
    if out.exists() and any(out.iterdir()):
        p.error('Output folder must be empty')
    out.mkdir(parents=True, exist_ok=True)
    manifest = {'job': job, 'status': 'running', 'input': str(args.input.resolve()),
                'host': args.host, 'installed': False, 'profile': profile}
    start = time.monotonic()
    remote_out = None

    def remote(command, **kwargs):
        return subprocess.run(['ssh', '-o', 'BatchMode=yes', '-o', 'ConnectTimeout=15', args.host,
                               shlex.join(list(map(str, command)))], check=True, **kwargs)

    try:
        home = remote(['pwd'], capture_output=True, text=True).stdout.strip()
        folder = home + '/character_candidates/' + job
        remote_out = folder + '/output'
        manifest['remote_dir'] = folder
        remote(['mkdir', folder])
        snapshot = out / 'source'
        snapshot.mkdir()
        for source, name in ((args.input, 'input.glb'), (args.profile, 'profile.json'),
                             (HERE / 'rig_character.py', 'rig_character.py'), (Path(__file__), 'run_rig.py')):
            shutil.copy2(source, snapshot / name)
        manifest['source_sha256'] = {f.name: hashlib.sha256(f.read_bytes()).hexdigest() for f in snapshot.iterdir()}
        subprocess.run(['scp', '-q', *map(str, snapshot.iterdir()), f'{args.host}:{folder}/'], check=True)
        with (out / 'build.log').open('w') as log:
            remote([home + '/apps/blender-4.5.14-linux-x64/blender', '-b', '--python-exit-code', '1',
                    '-P', folder + '/rig_character.py', '--', '--input', folder + '/input.glb',
                    '--profile', folder + '/profile.json', '--output-dir', remote_out],
                   stdout=log, stderr=subprocess.STDOUT)
        subprocess.run(['scp', '-q', '-r', f'{args.host}:{remote_out}/.', str(out)], check=True)
        manifest['status'] = 'awaiting_visual_review'
        print(f'Rig candidate: {out / "khanae_rigged.glb"}')
    except Exception as exc:
        manifest.update(status='failed', error=str(exc))
        if remote_out:
            subprocess.run(['scp', '-q', '-r', f'{args.host}:{remote_out}/.', str(out)])
        raise
    finally:
        manifest['elapsed_seconds'] = round(time.monotonic()-start, 3)
        (out / 'run.json').write_text(json.dumps(manifest, indent=2))


if __name__ == '__main__':
    main()
