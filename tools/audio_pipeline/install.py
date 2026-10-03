"""Prepare measured PCM candidates, then optionally install with byte backups.
Speech entries require an ASR review decision; no paid requests happen here.
"""
import argparse,hashlib,json,subprocess,wave
from pathlib import Path
import numpy as np
SR=44100

def db(value):return round(float(20*np.log10(max(value,1e-9))),2)
def write_wav(path,x):
    path.parent.mkdir(parents=True,exist_ok=True)
    with wave.open(str(path),'wb') as w:
        w.setnchannels(1);w.setsampwidth(2);w.setframerate(SR);w.writeframes((np.clip(x,-1,1)*32767).astype('<i2').tobytes())
def prepare(plan_path,install):
    plan=json.loads(Path(plan_path).read_text());base=Path(plan['output_directory']);ledger=json.loads((base/'ledger.json').read_text());rows=[]
    decisions=json.loads((base/'speech_review.json').read_text()) if (base/'speech_review.json').exists() else {}
    for job in plan['jobs']:
        record=ledger['jobs'].get(job['id'],{});spec=job['install']
        if record.get('status')!='complete':continue
        if spec.get('speech') and not decisions.get(job['id'],{}).get('accepted',False):continue
        source=Path(record['files'][0]);target=Path('assets/audio')/spec['file']
        result=subprocess.run(['ffmpeg','-v','error','-i',str(source),'-ac','1','-ar',str(SR),'-af','highpass=f=55','-f','f32le','-'],capture_output=True,check=True)
        x=np.frombuffer(result.stdout,dtype='<f4').astype(float);x-=np.mean(x)
        if len(x)<int(SR*.15) or not np.all(np.isfinite(x)):raise ValueError('Invalid audio '+str(source))
        if spec['loop']:
            # Fold tail onto head: continuous transition into the preserved middle.
            cross=int(SR*(3.0 if spec.get('music_state') else .20))
            if len(x)<cross*3:raise ValueError('Loop too short '+str(source))
            t=np.linspace(0,np.pi/2,cross)
            x=np.concatenate([x[-cross:]*np.cos(t)+x[:cross]*np.sin(t),x[cross:-cross]])
        else:
            # Preserve breaths and final consonants; trim only near-silent pads.
            envelope=np.max(np.abs(x.reshape(-1,1)),axis=1);active=np.flatnonzero(envelope>.0015)
            if not len(active):raise ValueError('Silent '+str(source))
            pad=int(SR*.07);x=x[max(0,active[0]-pad):min(len(x),active[-1]+pad)]
            fade=min(int(.006*SR),len(x)//8);x[:fade]*=np.linspace(0,1,fade);x[-fade:]*=np.linspace(1,0,fade)
        rms=np.sqrt(np.mean(x*x));peak=np.max(np.abs(x))
        transient_control=False
        if spec['loop'] and not spec.get('music_state') and peak>rms*10:
            # Smooth saturation controls isolated impulses without raising them
            # into the master limiter when matching a quiet continuous bed.
            knee=max(rms*6,1e-6);x=knee*np.tanh(x/knee);transient_control=True
            rms=np.sqrt(np.mean(x*x));peak=np.max(np.abs(x))
        gain=min(10**(spec['rms_dbfs']/20)/max(rms,1e-9),.70/max(peak,1e-9));x*=gain
        candidate=base/'prepared'/spec['file'];write_wav(candidate,x)
        info={'id':job['id'],'file':str(target),'source':str(source),'candidate':str(candidate),'seconds':round(len(x)/SR,3),'rms_dbfs':db(np.sqrt(np.mean(x*x))),'peak_dbfs':db(np.max(np.abs(x))),'loop':spec['loop'],'transient_control':transient_control,'sha256':hashlib.sha256(candidate.read_bytes()).hexdigest(),'installed':False}
        if install:
            backup=base/'backup'/spec['file']
            if target.exists() and not backup.exists():backup.parent.mkdir(parents=True,exist_ok=True);backup.write_bytes(target.read_bytes())
            target.write_bytes(candidate.read_bytes());info['installed']=True
        rows.append(info)
    if install and sum(r['id'].startswith('sfxloop_music') for r in rows)==3:
        Path('assets/audio/music_states.tres').write_text('[gd_resource type="Resource" format=3]\n\n[resource]\nmetadata/state_tracks = true\n')
    (base/'installed_manifest.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2))
    print(f'{len(rows)} files {"installed" if install else "prepared"} from {plan_path}')
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('plan');p.add_argument('--install',action='store_true');a=p.parse_args();prepare(a.plan,a.install)
