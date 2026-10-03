#!/usr/bin/env python3
"""Build a supplied static GLB locally using the existing cleanup and review gates."""
import argparse
import hashlib
import json
import math
from pathlib import Path
import re
import shutil
import subprocess
import time
import uuid

from validate_assets import check, inspect

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('id')
    p.add_argument('--mesh', type=Path, required=True)
    p.add_argument('--blender', type=Path, required=True)
    p.add_argument('--variant', default='a')
    p.add_argument('--profile', choices=['standard', 'quality'], default='quality')
    p.add_argument('--yaw', type=float, default=0)
    p.add_argument('--task-id', default='', help='Provider task ID for provenance')
    p.add_argument('--output-dir', type=Path)
    p.add_argument('--manifest', type=Path, default=HERE/'asset_manifest.json',
                   help='Alternate specifications for uninstalled future-library candidates')
    args = p.parse_args()
    manifest = json.loads(args.manifest.read_text())
    if args.id not in manifest['assets'] or not re.fullmatch('[a-z]', args.variant):
        p.error('Invalid asset ID or variant')
    if not math.isfinite(args.yaw) or not args.blender.is_file():
        p.error('Provide a finite yaw and an existing Blender executable')
    if args.mesh.suffix.lower() != '.glb' or not args.mesh.is_file():
        p.error('Provide one self-contained static GLB')
    inspect(args.mesh)  # Same static/external-resource preflight as remote builder.
    spec = manifest['assets'][args.id]
    if args.profile == 'quality' and 'quality_tris' not in spec:
        p.error('This asset has no quality budget; select standard')
    budget = spec['quality_tris'] if args.profile == 'quality' else spec['tris']
    mode = 'vertex' if spec['render_mode'] == 'vertex' else 'preserve'
    base = f'{args.id}_{spec["name"]}_{args.variant}'
    out = (args.output_dir or ROOT/'artifacts/prop_candidates'/f'{base}_local_{uuid.uuid4().hex[:10]}').resolve()
    if out.exists() and any(out.iterdir()):
        p.error('Output directory must be empty')
    out.mkdir(parents=True, exist_ok=True)
    run = dict(asset_id=args.id, variant=args.variant, file=base+'.glb', profile=args.profile,
               spec=spec, backend='supplied-static-mesh-local', input=str(args.mesh.resolve()),
               input_sha256=sha(args.mesh), provider_task_id=args.task_id,
               yaw=args.yaw, material_mode=mode, manifest=str(args.manifest.resolve()), installed=False,
               visual_review='required', status='running', stages=[])

    def save():
        (out/'run.json').write_text(json.dumps(run, indent=2)+'\n')

    def stage(name, fn):
        entry = dict(name=name, status='running')
        run['stages'].append(entry)
        save()
        start = time.monotonic()
        try:
            result = fn()
            entry['status'] = 'complete'
            return result
        except Exception as exc:
            entry.update(status='failed', error=str(exc))
            raise
        finally:
            entry['seconds'] = round(time.monotonic()-start, 3)
            save()

    save()
    try:
        snapshot = out/'pipeline_source'
        snapshot.mkdir()
        (snapshot/'.gdignore').write_text('Historical pipeline code; excluded from Godot.\n')
        for source in [Path(__file__), HERE/'gpu/blender_cleanup.py', HERE/'validate_assets.py',
                       HERE/'palette.json', args.manifest, HERE/'render_props.gd',
                       ROOT/'scripts/AssetLibrary.gd']:
            shutil.copy2(source, snapshot/source.name)
        run['script_sha256'] = {f.name: sha(f) for f in snapshot.iterdir()}
        shutil.copy2(args.mesh, out/'input.glb')
        run['blender_version'] = subprocess.check_output([str(args.blender), '--version'], text=True).splitlines()[0]
        candidate = out/(base+'.glb')
        with (out/'run.log').open('w') as log:
            stage('prepare_prop', lambda: subprocess.run([
                str(args.blender), '-b', '--python-exit-code', '1', '-P', str(snapshot/'blender_cleanup.py'), '--',
                '--in', str(out/'input.glb'), '--out', str(candidate), '--master', str(out/'master.glb'),
                '--tris', str(budget), '--fit', spec['fit'], '--meters', str(spec['meters']),
                '--category', spec['category'], '--material-mode', mode, '--input-colors', 'linear',
                '--palette', str(snapshot/'palette.json'), '--yaw', str(args.yaw),
                '--stats', str(out/'stats.json')], check=True, stdout=log, stderr=subprocess.STDOUT))

        def validate():
            _, problems, summary = check(candidate, manifest, args.profile)
            report = dict(passed=not problems, problems=problems, summary=summary)
            if not problems:
                report['geometry'] = inspect(candidate)
            (out/'validation.json').write_text(json.dumps(report, indent=2))
            if problems:
                raise ValueError('; '.join(problems))

        stage('validate', validate)
        run['candidate_sha256'] = sha(candidate)
        (out/'preview_manifest.json').write_text(json.dumps([dict(label=base, path=str(candidate))]))
        with (out/'preview.log').open('w') as log:
            stage('preview', lambda: subprocess.run([
                'godot', '--path', str(ROOT), '--script', str(HERE/'render_props.gd'), '--',
                str(out/'preview_manifest.json'), str(out/'preview.png')],
                check=True, timeout=180, stdout=log, stderr=subprocess.STDOUT))
        if not (out/'preview.png').is_file():
            raise RuntimeError('Missing four-angle review image')
        run['status'] = 'awaiting_visual_review'
        print(out)
    except Exception as exc:
        run.update(status='failed', error=str(exc))
        raise
    finally:
        save()


if __name__ == '__main__':
    main()
