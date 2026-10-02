#!/usr/bin/env python3
"""Build a reproducible prop candidate; installation is a separate reviewed step."""
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
from validate_assets import check, inspect

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('id')
    p.add_argument('--prompt', action='store_true')
    inputs = p.add_mutually_exclusive_group()
    inputs.add_argument('--image', type=Path)
    inputs.add_argument('--mesh', type=Path)
    p.add_argument('--source-run', type=Path, help='Completed native source run.json; same input image required')
    p.add_argument('--profile', choices=['standard','quality'])
    p.add_argument('--backend', choices=['trellis2','triposr'])
    p.add_argument('--variant', default='a')
    p.add_argument('--host', default='gpu')
    p.add_argument('--view', choices=['front','three-quarter-right','three-quarter-left'], default='front')
    p.add_argument('--yaw', type=float, help='Explicit up-axis rotation in degrees, overriding --view')
    p.add_argument('--mesh-colors', choices=['linear','srgb'], default='linear')
    p.add_argument('--retexture', action=argparse.BooleanOptionalAction, default=None)
    p.add_argument('--prepared-reference', type=Path, help='Already prepared image for texture-only mesh refinement')
    p.add_argument('--auto-square', action='store_true')
    p.add_argument('--output-dir', type=Path)
    p.add_argument('--skip-preview', action='store_true')
    p.add_argument('--skip-import', action='store_true', help='Compatibility option: candidates are never installed/imported')
    p.add_argument('--keep-remote', action='store_true', help='Compatibility option: intermediates are always retained')
    args = p.parse_args()
    if args.yaw is not None and not math.isfinite(args.yaw):
        p.error('--yaw must be finite')
    manifest = json.loads((HERE/'asset_manifest.json').read_text())
    if args.id not in manifest['assets']:
        p.error('Unknown asset ID; see asset_manifest.json')
    spec = manifest['assets'][args.id]
    if args.prompt:
        print(f"{args.id}: {spec['name']} ({spec['route']}, standard {spec['tris']} triangles)")
        prompt_key = 'quality_style_prompt' if (args.profile == 'quality' or (args.profile is None and 'quality_tris' in spec)) else 'style_prompt'
        print(manifest[prompt_key].replace('{desc}', spec['desc']))
        return
    if spec['route'] == 'meshy' and (args.image or args.retexture):
        p.error('Character generation uses Meshy; provide its reviewed static --mesh. See tools/character_pipeline/MESHY_SETUP.md')
    if not re.fullmatch('[a-z]', args.variant) or not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9_.@-]*', args.host):
        p.error('Invalid variant or host')
    source = args.image or args.mesh
    if source is None or not source.is_file():
        p.error('Provide one existing --image or --mesh')
    if args.mesh and source.suffix.lower() != '.glb':
        p.error('Use a self-contained GLB; external OBJ/FBX texture dependencies must be packed first')
    if args.mesh:
        try:
            inspect(source) # Reject animated/external/corrupt inputs before Blender can flatten them.
        except (ValueError, KeyError, IndexError, TypeError, OSError) as exc:
            p.error(f'Unsupported input mesh: {exc}')
    if args.image and (source.suffix.lower() not in ('.png','.jpg','.jpeg') or spec['route'] == 'proc'):
        p.error('Image route needs PNG/JPEG and an img3d asset; thin proc assets require --mesh')
    profile = args.profile or ('quality' if 'quality_tris' in spec else 'standard')
    if profile == 'quality' and 'quality_tris' not in spec:
        p.error('This instanced/procedural asset has no quality budget; use standard')
    backend = args.backend or ('trellis2' if profile == 'quality' else 'triposr')
    mode = 'vertex' if spec['render_mode'] == 'vertex' else 'preserve'
    if args.image and backend == 'trellis2' and mode == 'vertex':
        p.error('Instanced vegetation requires vertex colours; use TripoSR or supply a vertex-coloured mesh')
    if args.image and backend == 'triposr':
        mode = 'vertex'
    retexture = args.retexture if args.retexture is not None else bool(args.image and backend == 'trellis2')
    if retexture and (mode == 'vertex' or (args.mesh and not args.prepared_reference)):
        p.error('Retexturing requires the material route and a prepared reference')
    if args.source_run and (not args.image or backend != 'trellis2'):
        p.error('--source-run is for TRELLIS image builds only')
    if not args.skip_preview and not shutil.which('godot'):
        p.error('Godot required for visual preview; use --skip-preview only on headless hosts')
    budget = spec.get('quality_tris', spec['tris']) if profile == 'quality' else spec['tris']
    base = f'{args.id}_{spec["name"]}_{args.variant}'
    job = base+'_'+uuid.uuid4().hex[:10]
    out = (args.output_dir or ROOT/'artifacts/prop_candidates'/job).resolve()
    if out.exists() and (not out.is_dir() or any(out.iterdir())):
        p.error('Output folder must be empty')
    out.mkdir(parents=True, exist_ok=True)
    run = {'job':job, 'asset_id':args.id, 'variant':args.variant, 'file':base+'.glb',
           'profile':profile, 'spec':spec, 'backend':backend if args.image else 'mesh',
           'input':str(source.resolve()), 'input_sha256':sha(source), 'host':args.host,
           'material_mode':mode, 'retexture':retexture, 'texture_steps':24, 'texture_seed':42,
           'view':args.view, 'yaw':args.yaw, 'auto_square':args.auto_square, 'mesh_colors':args.mesh_colors,
           'visual_review':'required', 'installed':False, 'status':'running', 'stages':[]}
    start = time.monotonic()
    remote_out = None

    def save():
        (out/'run.json').write_text(json.dumps(run,indent=2)+'\n')

    def stage(name, action):
        record = {'name':name,'status':'running'};run['stages'].append(record);save()
        print(f'[{job}] {name}',flush=True); begin=time.monotonic()
        try:
            result=action();record['status']='complete';return result
        except Exception as exc:
            record.update(status='failed',error=str(exc));raise
        finally:
            record['seconds']=round(time.monotonic()-begin,3);save()

    def remote(command, **kwargs):
        return subprocess.run(['ssh','-o','BatchMode=yes','-o','ConnectTimeout=15',args.host,
                               shlex.join(list(map(str,command)))],check=True,**kwargs)

    def gpu_health(required):
        health=remote(['nvidia-smi','--query-gpu=name,memory.total,memory.free,utilization.gpu',
                       '--format=csv,noheader,nounits'],capture_output=True,text=True).stdout.strip()
        run.setdefault('gpu_checks',[]).append(health)
        if not health or any(x in health.upper() for x in ('N/A','ERR!')) or int(health.splitlines()[0].split(',')[2]) < required:
            raise RuntimeError(f'Need a healthy GPU with {required} MiB free: {health}')

    save()
    try:
        snapshot=out/'pipeline_source';snapshot.mkdir()
        (snapshot/'.gdignore').write_text('Historical pipeline code; never register these classes in Godot.\n')
        for f in [Path(__file__), HERE/'validate_assets.py', HERE/'gpu/blender_cleanup.py',
                  HERE/'gpu/prop_generate.py', HERE/'palette.json', HERE/'asset_manifest.json',
                  HERE/'render_props.gd', ROOT/'scripts/AssetLibrary.gd',
                  ROOT/'tools/character_pipeline/run_character.py']:
            shutil.copy2(f,snapshot/f.name)
        run['script_sha256']={f.name:sha(f) for f in snapshot.iterdir()}
        shutil.copy2(source,out/('reference'+source.suffix.lower() if args.image else 'input.glb'))
        home=remote(['pwd'],capture_output=True,text=True).stdout.strip()
        folder=home+'/asset_pipeline/work/'+job;remote_out=folder+'/output'
        run['remote_dir']=folder
        remote(['mkdir','-p',remote_out])
        subprocess.run(['scp','-q',str(snapshot/'blender_cleanup.py'),str(snapshot/'prop_generate.py'),
                        str(snapshot/'palette.json'),f'{args.host}:{folder}/'],check=True)
        blender=home+'/apps/blender-4.5.14-linux-x64/blender'
        python=home+'/aienv/bin/python3'
        reference=None
        with (out/'run.log').open('w') as log:
            def execute(name, command):
                return stage(name,lambda:remote(command,stdout=log,stderr=subprocess.STDOUT))

            if args.image and backend=='trellis2':
                source_run=args.source_run
                if source_run is None:
                    stage('generate_source',lambda:subprocess.run([
                        sys.executable,str(ROOT/'tools/character_pipeline/run_character.py'),
                        '--image',str(source.resolve()),'--name',base.lower(),'--host',args.host,
                        '--backend','trellis2','--resolution','1024','--remesh-resolution','512',
                        '--steps','12','--seed','1','--noise-seed','18','--save-material-cache','--source-only',
                        '--output-dir',str(out/'source')],check=True,stdout=log,stderr=subprocess.STDOUT))
                    source_run=out/'source/run.json'
                data=json.loads(source_run.read_text())
                if data.get('status')!='complete' or data.get('backend')!='trellis2' or data.get('input_sha256')!=sha(source):
                    raise ValueError('Source run must be complete TRELLIS for the exact reference image')
                raw_files=list(source_run.parent.glob('*_raw.glb'))
                if len(raw_files)!=1:
                    raise ValueError('Expected one downloaded raw GLB beside source run.json')
                run['source_run']=str(source_run.resolve());run['material_cache']=data.get('material_cache')
                shutil.copy2(source_run,out/'source_run.json')
                subprocess.run(['scp','-q',str(raw_files[0]),f'{args.host}:{folder}/input.glb'],check=True)
                reference=folder+'/prepared_reference.png'
                subprocess.run(['scp','-q',str(source_run.parent/'prepared_input.png'),f'{args.host}:{reference}'],check=True)
                raw=folder+'/input.glb'
            elif args.image:
                stage('gpu_preflight',lambda:gpu_health(6000))
                image=folder+'/reference'+source.suffix.lower()
                subprocess.run(['scp','-q',str(source.resolve()),f'{args.host}:{image}'],check=True)
                raw=remote_out+'/raw.glb'
                execute('generate_source',[python,folder+'/prop_generate.py','--image',image,'--out',raw])
            else:
                raw=folder+'/input.glb'
                subprocess.run(['scp','-q',str(source.resolve()),f'{args.host}:{raw}'],check=True)
                if args.prepared_reference:
                    reference=folder+'/prepared_reference.png'
                    run['prepared_reference_sha256']=sha(args.prepared_reference)
                    shutil.copy2(args.prepared_reference,out/'prepared_reference.png')
                    subprocess.run(['scp','-q',str(args.prepared_reference.resolve()),f'{args.host}:{reference}'],check=True)

            def cleanup(name, input_file, output_file, yaw=0, master=False):
                command=[blender,'-b','--python-exit-code','1','-P',folder+'/blender_cleanup.py','--',
                    '--in',input_file,'--out',output_file,'--tris',budget,'--fit',spec['fit'],
                    '--meters',spec['meters'],'--category',spec['category'],'--material-mode',mode,
                    '--input-colors','srgb' if args.image and backend=='triposr' else args.mesh_colors,
                    '--palette',folder+'/palette.json','--yaw',yaw,'--stats',output_file+'.stats.json']
                if master:command.extend(['--master',remote_out+'/master.glb'])
                if args.auto_square and master:command.append('--auto-square')
                if args.image and backend=='triposr':command.extend(['--ref-image',remote_out+'/input_rgba.png'])
                execute(name,command)

            yaw={'front':0,'three-quarter-right':45,'three-quarter-left':-45}[args.view]
            if args.yaw is not None: yaw=args.yaw
            cleaned=remote_out+'/prepared.glb' if retexture else remote_out+'/'+base+'.glb'
            cleanup('prepare_prop',raw,cleaned,yaw,True)
            if retexture:
                stage('texture_gpu_preflight',lambda:gpu_health(20000))
                runtime=home+'/tools/trellis2.c/build-cuda'
                run['texture_runtime_sha256']=remote(['sha256sum',runtime+'/trellis2-texture-mesh',runtime+'/libtrellis2_c.so'],capture_output=True,text=True).stdout.strip()
                execute('fresh_texture',['env','TRELLIS_VKMESH_HOST_MEMORY=1',runtime+'/trellis2-texture-mesh',
                    '--model',home+'/tools/TRELLIS.2/TRELLIS.2-4B','--dino',home+'/tools/TRELLIS.2/dinov3-vitl16-pretrain-lvd1689m',
                    '--input',cleaned,'--image',reference,'--image-prepared','--resolution','1024',
                    '--texture-size','2048','--steps','24','--seed','42',
                    '--shape-latent-output',remote_out+'/shape.slat','--output',remote_out+'/retextured.glb'])
                cleanup('restore_size',remote_out+'/retextured.glb',remote_out+'/'+base+'.glb')
        stage('download',lambda:subprocess.run(['scp','-q','-r',f'{args.host}:{remote_out}/.',str(out)],check=True))
        candidate=out/(base+'.glb')
        def validate():
            _,problems,summary=check(candidate,manifest,profile)
            report={'passed':not problems,'problems':problems,'summary':summary}
            if not problems:report['geometry']=inspect(candidate)
            (out/'validation.json').write_text(json.dumps(report,indent=2))
            if problems:raise ValueError('; '.join(problems))
        stage('validate',validate)
        run['candidate_sha256']=sha(candidate)
        rows=[{'label':'Candidate','path':str(candidate)}]
        if args.id=='S1':rows.insert(0,{'label':'Current procedural hut','procedural':'S1'})
        (out/'preview_manifest.json').write_text(json.dumps(rows,indent=2))
        if not args.skip_preview:
            with (out/'preview.log').open('w') as log:
                stage('preview',lambda:subprocess.run(['godot','--path',str(ROOT),
                    '--script',str(HERE/'render_props.gd'),'--',str(out/'preview_manifest.json'),str(out/'preview.png')],
                    check=True,timeout=180,stdout=log,stderr=subprocess.STDOUT))
            if not (out/'preview.png').is_file():raise RuntimeError('Missing rendered preview')
        run['status']='awaiting_visual_review'
        print(f'Candidate: {candidate}\nReview: {out}',flush=True)
    except Exception as exc:
        run.update(status='failed',error=str(exc))
        if remote_out:
            partial=out/'partial';partial.mkdir(exist_ok=True)
            subprocess.run(['scp','-q','-r',f'{args.host}:{remote_out}/.',str(partial)])
        raise
    finally:
        run['elapsed_seconds']=round(time.monotonic()-start,3);save()


if __name__=='__main__':
    main()
