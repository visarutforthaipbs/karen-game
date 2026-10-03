"""Build rotation-only Meshy motion candidates on approved rigs. Never installs."""
import argparse,copy,json,math,struct,sys
from pathlib import Path
import numpy as np
from mathutils import Matrix,Quaternion,Vector
ROOT=next(p for p in Path(__file__).resolve().parents if (p/'project.godot').is_file())
sys.path.insert(0,str(ROOT/'tools/character_pipeline'))
from retarget_meshy_overlay import state,matrix,MAP,read_glb,accessor

def channels(doc,binary,animation):
    return [(c['target']['node'],c['target']['path'],
             [x[0] for x in accessor(doc,binary,animation['samplers'][c['sampler']]['input'])],
             accessor(doc,binary,animation['samplers'][c['sampler']]['output']))
            for c in animation['channels']]

def sample(local,tracks,t):
    import bisect
    out=[m.copy() for m in local]
    for i,path,times,rows in tracks:
        j=min(max(bisect.bisect_right(times,t)-1,0),len(times)-1);k=min(j+1,len(times)-1)
        f=0 if times[k]==times[j] else max(0,min(1,(t-times[j])/(times[k]-times[j])))
        loc,q,scale=out[i].decompose()
        if path=='rotation':q=Quaternion((rows[j][3],*rows[j][:3])).slerp(Quaternion((rows[k][3],*rows[k][:3])),f)
        elif path=='translation':loc=Vector(rows[j]).lerp(Vector(rows[k]),f)
        elif path=='scale':scale=Vector(rows[j]).lerp(Vector(rows[k]),f)
        out[i]=Matrix.LocRotScale(loc,q,scale)
    return out

def main():
    p=argparse.ArgumentParser()
    for name in ['source','target','output']:p.add_argument('--'+name,type=Path,required=True)
    p.add_argument('--clip',choices=['Walk','Run','Escort','Idle','ToolUse','Talk','Granary','Scan','Photograph','Point','RadioTalk'],required=True)
    p.add_argument('--gain',type=float,default=.65)
    p.add_argument('--torso-only',action='store_true')
    p.add_argument('--photograph-grip',action='store_true')
    a=p.parse_args(sys.argv[sys.argv.index('--')+1:]);assert not a.output.exists()
    sd,sb=read_glb(a.source);td,tb=read_glb(a.target);old=copy.deepcopy(td);oldbytes=tb
    sp,sl,sw,srest=state(sd,sb);tp,tl,tw,trest=state(td,tb)
    sn={n['name']:i for i,n in enumerate(sd['nodes']) if 'name' in n};tn={n['name']:i for i,n in enumerate(td['nodes']) if 'name' in n}
    baseline=next(x for x in td['animations'] if x['name']==a.clip)
    st=channels(sd,sb,sd['animations'][0]);bt=channels(td,tb,baseline)
    duration=max(x[2][-1] for x in bt);source_duration=max(x[2][-1] for x in st)
    frames=max(2,round(duration*60));times=[duration*i/frames for i in range(frames+1)]
    joints=td['skins'][0]['joints'];rot={i:[] for i in joints};pos={i:[] for i in joints}
    # Vertex-based grounding keeps original skin/mesh data while preventing new gait penetration.
    ibm=[np.array(matrix(x),dtype=float) for x in accessor(td,tb,td['skins'][0]['inverseBindMatrices'])]
    primitives=td['meshes'][0]['primitives'];verts=[];weights=[];influences=[]
    for primitive in primitives:
        at=primitive['attributes'];v=np.array(accessor(td,tb,at['POSITION']));verts.append(np.column_stack((v,np.ones(len(v)))))
        weights.append(np.array(accessor(td,tb,at['WEIGHTS_0'])));influences.append(np.array(accessor(td,tb,at['JOINTS_0']),dtype=int))
    verts=np.concatenate(verts);weights=np.concatenate(weights);influences=np.concatenate(influences)
    root=tn['Root'];ground=[]
    for time in times:
        source=sample(sl,st,time/duration*source_duration);base=sample(tl,bt,time)
        posed=[m.copy() for m in base]
        locomotion=a.clip in ['Walk','Run','Escort']
        for name in MAP:
            if name in ['Hips','Spine','Chest','Neck','Head']:continue
            if a.torso_only or (not locomotion and name.startswith(('Thigh','Shin','Foot'))):continue
            i=tn[name];j=sn[MAP[name]]
            # Conjugate LOCAL bind-relative delta through bone bind axes. Never transfer source hip translation.
            sparent=srest[sp[j]] if sp[j] in srest else sw(sp[j],sl)
            tparent=trest[tp[i]] if tp[i] in trest else tw(tp[i],tl)
            sr=(sparent.inverted()@srest[j]).to_quaternion()
            tr=(tparent.inverted()@trest[i]).to_quaternion()
            delta=sr.inverted()@source[j].to_quaternion()
            axes=trest[i].to_quaternion().inverted()@srest[j].to_quaternion()
            target=tr@axes@delta@axes.inverted()
            loc,q,scale=base[i].decompose()
            gain=a.gain if name.startswith(('Thigh','Shin','Foot')) else a.gain*.5
            if not locomotion:gain*=math.sin(math.pi*time/duration)**2
            posed[i]=Matrix.LocRotScale(loc,q.slerp(target,gain),scale)
        if not locomotion:
            reference=sample(sl,st,0)
            for name in ['Chest','Head']:
                i=tn[name];j=sn[MAP[name]]
                delta=source[j].to_quaternion()@reference[j].to_quaternion().inverted()
                axes=srest[sp[j]].to_quaternion()
                delta=axes@delta@axes.inverted()
                if delta.w<0:delta.negate()
                delta=Quaternion().slerp(delta,min(a.gain,.15)*math.sin(math.pi*time/duration)**2)
                parent=tw(tp[i],posed).to_quaternion()
                loc,q,scale=posed[i].decompose()
                posed[i]=Matrix.LocRotScale(loc,parent.inverted()@delta@parent@q,scale)
        if a.photograph_grip:
            assert a.clip=='Photograph'
            blend=math.sin(math.pi*time/duration)**2
            upper,lower,hand=[tn[x+'.R'] for x in ['UpperArm','Forearm','Hand']]
            initial=tw(hand,posed).translation
            goal=initial.lerp(Vector((-.22,.73,.32)),blend)
            # CCD solves the authored forearm/upper arm lengths without changing
            # skin, translations or the pointing/radio clips.
            for iteration in range(12):
                for bone in [lower,upper]:
                    world=tw(bone,posed);origin=world.translation
                    current=tw(hand,posed).translation-origin;target=goal-origin
                    if min(current.length,target.length)<1e-6:continue
                    delta=current.rotation_difference(target)
                    basis=world.to_quaternion();loc,q,scale=posed[bone].decompose()
                    posed[bone]=Matrix.LocRotScale(loc,q@basis.inverted()@delta@basis,scale)
        # Blend the end of the loop back into its first frame rather than adding a one-frame discontinuity.
        if time==0:first=[m.copy() for m in posed]
        if time/duration>.9:
            f=(time/duration-.9)/.1;f=f*f*(3-2*f)
            for i in joints:
                loc,q,scale=posed[i].decompose();fl,fq,fs=first[i].decompose()
                posed[i]=Matrix.LocRotScale(loc.lerp(fl,f),q.slerp(fq,f),scale.lerp(fs,f))
        palette=np.array([np.array(tw(i,posed),dtype=float)@b for i,b in zip(joints,ibm)])
        skin=np.einsum('vwij,vj->vwi',palette[influences],verts)
        skin=(skin*weights[:,:,None]).sum(axis=1)
        floor=float(skin[:,1].min());ground.append(floor)
        loc,q,scale=posed[root].decompose()
        parent=tw(tp[root],posed) if root in tp else Matrix.Identity(4)
        loc+=parent.to_3x3().inverted()@Vector((0,-floor,0))
        posed[root]=Matrix.LocRotScale(loc,q,scale)
        for i in joints:
            loc,q,scale=posed[i].decompose();q.normalize()
            row=(q.x,q.y,q.z,q.w)
            if rot[i] and sum(x*y for x,y in zip(row,rot[i][-1]))<0:row=tuple(-x for x in row)
            rot[i].append(row);pos[i].append(tuple(loc))
    for i in joints:rot[i][-1]=rot[i][0];pos[i][-1]=pos[i][0]
    def append(rows,kind):
        nonlocal tb
        width={'SCALAR':1,'VEC3':3,'VEC4':4}[kind];payload=b''.join(struct.pack('<'+'f'*width,*row) for row in rows)
        tb+=b'\0'*((-len(tb))%4);offset=len(tb);tb+=payload
        td['bufferViews'].append({'buffer':0,'byteOffset':offset,'byteLength':len(payload)})
        acc={'bufferView':len(td['bufferViews'])-1,'componentType':5126,'count':len(rows),'type':kind}
        if kind=='SCALAR':acc.update(min=[rows[0][0]],max=[rows[-1][0]])
        td['accessors'].append(acc);return len(td['accessors'])-1
    timeacc=append([(t,) for t in times],'SCALAR');anim={'name':a.clip,'channels':[],'samplers':[]}
    for i in joints:
        for path,rows,kind in [('rotation',rot[i],'VEC4'),('translation',pos[i],'VEC3')]:
            anim['channels'].append({'sampler':len(anim['samplers']),'target':{'node':i,'path':path}})
            anim['samplers'].append({'input':timeacc,'output':append(rows,kind),'interpolation':'LINEAR'})
    td['animations']=[anim if x['name']==a.clip else x for x in td['animations']]
    for key in ['nodes','skins','meshes','materials','textures','images']:assert td.get(key)==old.get(key)
    assert tb[:len(oldbytes)]==oldbytes
    td['buffers'][0]['byteLength']=len(tb);data=json.dumps(td,separators=(',',':')).encode();data+=b' '*((-len(data))%4);tb+=b'\0'*((-len(tb))%4)
    a.output.parent.mkdir(parents=True,exist_ok=True)
    a.output.write_bytes(struct.pack('<4sII',b'glTF',2,28+len(data)+len(tb))+struct.pack('<II',len(data),0x4e4f534a)+data+struct.pack('<II',len(tb),0x004e4942)+tb)
    report={'clip':a.clip,'source':str(a.source),'gain':a.gain,'seconds':duration,'original_floor_range':[min(ground),max(ground)],'review':'candidate only'}
    a.output.with_suffix('.json').write_text(json.dumps(report,indent=2));print(json.dumps(report))
if __name__=='__main__':main()
