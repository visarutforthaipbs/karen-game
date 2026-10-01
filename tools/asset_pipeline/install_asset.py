#!/usr/bin/env python3
"""Promote one visually reviewed candidate; validate first and roll back failed imports."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import uuid
from validate_assets import check

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def godot_import(root):
    result = subprocess.run(['godot','--headless','--editor','--quit','--path',str(root)],
                            capture_output=True,text=True,timeout=180)
    if result.returncode or 'SCRIPT ERROR:' in result.stdout+result.stderr or 'ERROR:' in result.stdout+result.stderr:
        raise RuntimeError('Godot import failed:\n'+result.stdout+result.stderr)
    return result.stdout+result.stderr


def install(folder, reviewed, root=ROOT, importer=godot_import):
    if not reviewed:
        raise ValueError('Visual review required: inspect reference and four-angle preview before --reviewed')
    folder=Path(folder).resolve();root=Path(root)
    run=json.loads((folder/'run.json').read_text())
    manifest=json.loads((HERE/'asset_manifest.json').read_text())
    spec=manifest['assets'][run['asset_id']]
    name=f"{run['asset_id']}_{spec['name']}_{run['variant']}.glb"
    if run['variant'] not in 'abcdefghijklmnopqrstuvwxyz' or len(run['variant'])!=1:
        raise ValueError('Invalid variant')
    if run.get('status')!='awaiting_visual_review' or run.get('file')!=name or run.get('profile') not in ('standard','quality'):
        raise ValueError('Candidate build is not ready for review')
    candidate=folder/name
    if digest(candidate)!=run.get('candidate_sha256'):
        raise ValueError('Candidate changed since build; rebuild and review it')
    _,problems,_=check(candidate,manifest,run['profile'])
    if problems:
        raise ValueError('Candidate rejected before installation: '+'; '.join(problems))
    destination=root/'assets/props'/name
    destination.parent.mkdir(parents=True,exist_ok=True)
    installation=folder/('installation_'+uuid.uuid4().hex[:10]);installation.mkdir()
    backup=installation/'previous.glb'
    existed=destination.exists()
    if existed:shutil.copy2(destination,backup)
    record={'destination':str(destination),'sha256':digest(candidate),'previous_exists':existed,
            'visual_review':'reviewed','status':'installing'}
    temp=None
    try:
        with tempfile.NamedTemporaryFile(dir=destination.parent,suffix='.tmp',delete=False) as f:
            temp=Path(f.name)
        shutil.copyfile(candidate,temp)
        os.replace(temp,destination)
        (installation/'import.log').write_text(importer(root))
        record['status']='installed'
    except Exception as exc:
        if existed:os.replace(backup,destination)
        else:destination.unlink(missing_ok=True)
        record.update(status='rolled_back',error=str(exc))
        try:
            (installation/'rollback_import.log').write_text(importer(root))
        except Exception as recovery:
            record['rollback_import_error']=str(recovery)
        raise
    finally:
        if temp:temp.unlink(missing_ok=True)
        (installation/'result.json').write_text(json.dumps(record,indent=2))
    return destination


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('candidate',type=Path)
    p.add_argument('--reviewed',action='store_true')
    args=p.parse_args()
    print('Installed:',install(args.candidate,args.reviewed))


if __name__=='__main__':
    main()
